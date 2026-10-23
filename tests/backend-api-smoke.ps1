param([string]$BaseUrl = 'http://localhost:8080', [switch]$SmokeOnly)

$ErrorActionPreference = 'Stop'
$script:results = [System.Collections.Generic.List[string]]::new()

function Invoke-Api([string]$Method, [string]$Path, $Body = $null, [hashtable]$Headers = @{}) {
    $arguments = @{ Uri = "$BaseUrl$Path"; Method = $Method; Headers = $Headers; UseBasicParsing = $true }
    if ($null -ne $Body) {
        $arguments.ContentType = 'application/json'
        $arguments.Body = $Body | ConvertTo-Json -Depth 10 -Compress
    }
    try {
        $response = Invoke-WebRequest @arguments
        $parsed = if ($response.Content) { $response.Content | ConvertFrom-Json } else { $null }
        return @{ Status = [int]$response.StatusCode; Body = $parsed }
    } catch {
        $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
        return @{ Status = $status; Body = $null }
    }
}

function Db-Scalar([string]$Database, [string]$Sql) {
    $value = docker exec --env MYSQL_PWD=ebanking docker-mysql-1 mysql --batch --skip-column-names --user=ebanking $Database -e $Sql
    if ($LASTEXITCODE -ne 0) { throw "Database query failed: $Sql" }
    return [string]($value | Select-Object -First 1)
}

function Check([string]$Id, [bool]$Passed, [string]$Observed) {
    $state = if ($Passed) { 'PASS' } else { 'FAIL' }
    $line = "$Id $state - $Observed"
    $script:results.Add($line)
    Write-Output $line
}

$suffix = [guid]::NewGuid().ToString('N').Substring(0, 12)
$email = "api-$suffix@example.test"
$mobile = '9' + (Get-Random -Minimum 100000000 -Maximum 999999999)
$password = 'TestPassword123!'
$registration = @{ email = $email; password = $password; legalName = 'API Test User'; mobileNumber = $mobile; dateOfBirth = '1990-01-01' }
$registered = Invoke-Api POST '/api/v1/auth/register' $registration
$customerId = $registered.Body.customerId
Check 'A1-register' ($registered.Status -eq 201 -and $customerId -and $registered.Body.accessToken) "HTTP $($registered.Status), customerId=$customerId"
if (-not $customerId) { Write-Output 'BLOCKED: authenticated service tests require A1 registration'; exit 1 }

$customerCount = Db-Scalar 'user_kyc_db' "SELECT COUNT(*) FROM customers WHERE email='$email'"
$credentialCount = Db-Scalar 'user_kyc_db' "SELECT COUNT(*) FROM credentials WHERE customer_id=UUID_TO_BIN('$customerId') AND password_hash<>'$password'"
Check 'A1-database' ($customerCount -eq '1' -and $credentialCount -eq '1') "customers=$customerCount, hashedCredentials=$credentialCount"
$duplicate = Invoke-Api POST '/api/v1/auth/register' $registration
Check 'A1-duplicate' ($duplicate.Status -eq 409) "HTTP $($duplicate.Status)"
$invalidRegistration = Invoke-Api POST '/api/v1/auth/register' @{ email='bad'; password='short'; legalName=''; mobileNumber=''; dateOfBirth='1990-01-01' }
Check 'A1-invalid' ($invalidRegistration.Status -eq 400) "HTTP $($invalidRegistration.Status)"

$login = Invoke-Api POST '/api/v1/auth/login' @{ email=$email; password=$password }
Check 'A2-login' ($login.Status -eq 200 -and $login.Body.accessToken) "HTTP $($login.Status), accessTokenPresent=$([bool]$login.Body.accessToken)"
$wrongLogin = Invoke-Api POST '/api/v1/auth/login' @{ email=$email; password='WrongPassword123!' }
Check 'A2-wrong-password' ($wrongLogin.Status -eq 401) "HTTP $($wrongLogin.Status)"
$badOtp = Invoke-Api POST "/api/v1/auth/mfa/verify?customerId=$customerId&otp=123456"
Check 'A3-invalid-otp' ($badOtp.Status -eq 401 -or $badOtp.Status -eq 403) "HTTP $($badOtp.Status)"
$unenrolledOtp = Invoke-Api POST "/api/v1/auth/mfa/verify?customerId=$customerId&otp=000000"
Check 'A3-unenrolled-otp' ($unenrolledOtp.Status -eq 401 -or $unenrolledOtp.Status -eq 403) "HTTP $($unenrolledOtp.Status); unenrolled challenge must be rejected"

$bearer = @{ Authorization = "Bearer $($login.Body.accessToken)"; 'X-Customer-Id' = $customerId }
$unauthorized = Invoke-Api GET '/api/v1/accounts' $null @{ 'X-Customer-Id' = $customerId }
Check 'X1-no-token' ($unauthorized.Status -eq 401) "HTTP $($unauthorized.Status)"
$refreshAsAccess = Invoke-Api GET '/api/v1/accounts' $null @{ Authorization="Bearer $($login.Body.refreshToken)"; 'X-Customer-Id'=$customerId }
Check 'X1-refresh-is-not-access' ($refreshAsAccess.Status -eq 401) "HTTP $($refreshAsAccess.Status)"
$otherCustomer = [guid]::NewGuid().ToString()
$forgedHeader = Invoke-Api GET '/api/v1/accounts' $null @{ Authorization=$bearer.Authorization; 'X-Customer-Id'=$otherCustomer }
Check 'X1-forged-header' ($forgedHeader.Status -eq 200 -and @($forgedHeader.Body).Count -eq 0) "HTTP $($forgedHeader.Status), otherCustomerHeaderIgnored=$(@($forgedHeader.Body).Count -eq 0)"
$foreignAccount = Invoke-Api POST '/api/v1/accounts' @{ customerId=$otherCustomer; type='SAVINGS'; minimumBalance=0 } $bearer
Check 'X1-foreign-account-body' ($foreignAccount.Status -eq 403) "HTTP $($foreignAccount.Status)"
$createAccount = Invoke-Api POST '/api/v1/accounts' @{ customerId=$customerId; type='SAVINGS'; minimumBalance=0 } $bearer
$accountId = $createAccount.Body.id
Check 'B1-create' ($createAccount.Status -eq 201 -and $accountId -and $createAccount.Body.status -eq 'ACTIVE') "HTTP $($createAccount.Status), accountId=$accountId"
if ($accountId) {
    $accountCount = Db-Scalar 'account_db' "SELECT COUNT(*) FROM accounts WHERE id=UUID_TO_BIN('$accountId') AND customer_id=UUID_TO_BIN('$customerId')"
    Check 'B1-database' ($accountCount -eq '1') "accounts=$accountCount"
}
$invalidAccount = Invoke-Api POST '/api/v1/accounts' @{ customerId=$customerId; type='SAVINGS'; minimumBalance=-1 } $bearer
Check 'B1-negative-minimum' ($invalidAccount.Status -eq 400) "HTTP $($invalidAccount.Status)"
$accounts = Invoke-Api GET '/api/v1/accounts' $null $bearer
$accountFound = @($accounts.Body | Where-Object { $_.id -eq $accountId }).Count -eq 1
Check 'B2-portfolio' ($accounts.Status -eq 200 -and $accountFound) "HTTP $($accounts.Status), createdAccountFound=$accountFound"
$forgedAfterCreate = Invoke-Api GET '/api/v1/accounts' $null @{ Authorization=$bearer.Authorization; 'X-Customer-Id'=$otherCustomer }
$spoofResisted = @($forgedAfterCreate.Body | Where-Object { $_.id -eq $accountId }).Count -eq 1
Check 'X1-subject-overrides-header' ($forgedAfterCreate.Status -eq 200 -and $spoofResisted) "HTTP $($forgedAfterCreate.Status), ownAccountReturned=$spoofResisted"

$quote = Invoke-Api POST '/api/v1/loans/quote' @{ principal=120000; annualRate=12; months=12 } $bearer
Check 'D1-quote' ($quote.Status -eq 200 -and [math]::Abs([double]$quote.Body.monthlyEmi - 10661.85) -lt 0.10) "HTTP $($quote.Status), EMI=$($quote.Body.monthlyEmi)"
$badQuote = Invoke-Api POST '/api/v1/loans/quote' @{ principal=-1; annualRate=12; months=12 } $bearer
Check 'D1-negative-principal' ($badQuote.Status -eq 400) "HTTP $($badQuote.Status)"
$zeroTenure = Invoke-Api POST '/api/v1/loans/quote' @{ principal=1000; annualRate=12; months=0 } $bearer
Check 'D1-zero-tenure' ($zeroTenure.Status -eq 400) "HTTP $($zeroTenure.Status)"

$card = Invoke-Api POST '/api/v1/cards' @{ type='DEBIT' } $bearer
$cardId = $card.Body.id
Check 'E1-issue' ($card.Status -eq 201 -and $cardId) "HTTP $($card.Status), cardId=$cardId"
$invalidCard = Invoke-Api POST '/api/v1/cards' @{ type='GIFT' } $bearer
Check 'E1-invalid-type' ($invalidCard.Status -eq 400) "HTTP $($invalidCard.Status)"
if ($cardId) {
    $cardCount = Db-Scalar 'card_db' "SELECT COUNT(*) FROM cards WHERE id=UUID_TO_BIN('$cardId')"
    Check 'E1-database' ($cardCount -eq '1') "cards=$cardCount"
    $getCard = Invoke-Api GET "/api/v1/cards?id=$cardId" $null $bearer
    Check 'E2-get' ($getCard.Status -eq 200 -and $getCard.Body.id -eq $cardId) "HTTP $($getCard.Status)"
    $blocked = Invoke-Api POST "/api/v1/cards/$cardId/block" $null $bearer
    Check 'E3-block' ($blocked.Status -eq 200 -and $blocked.Body.status -eq 'BLOCKED') "HTTP $($blocked.Status), status=$($blocked.Body.status)"
    $unblocked = Invoke-Api POST "/api/v1/cards/$cardId/unblock" $null $bearer
    Check 'E3-unblock' ($unblocked.Status -eq 200 -and $unblocked.Body.status -eq 'ACTIVE') "HTTP $($unblocked.Status), status=$($unblocked.Body.status)"
    $controls = Invoke-Api PATCH "/api/v1/cards/$cardId/controls" @{ internationalEnabled=$true; ecommerceEnabled=$false } $bearer
    Check 'E4-controls' ($controls.Status -eq 200 -and $controls.Body.internationalEnabled -and -not $controls.Body.ecommerceEnabled) "HTTP $($controls.Status)"
    $persistedControls = Db-Scalar 'card_db' "SELECT COUNT(*) FROM card_controls WHERE card_id=UUID_TO_BIN('$cardId') AND international_enabled=1 AND ecommerce_enabled=0"
    Check 'E4-database' ($persistedControls -eq '1') "matchingControlRows=$persistedControls"
}
$unknownCard = Invoke-Api GET "/api/v1/cards?id=$([guid]::NewGuid())" $null $bearer
Check 'E2-unknown' ($unknownCard.Status -eq 404) "HTTP $($unknownCard.Status)"

$alert = Invoke-Api POST '/api/v1/fraud-alerts' @{ customerId=$customerId; amount=100001; newGeography=$false; eventsLastHour=1 } $bearer
Check 'F1-high-alert' (($alert.Status -eq 200 -or $alert.Status -eq 201) -and $alert.Body.severity -eq 'HIGH') "HTTP $($alert.Status), severity=$($alert.Body.severity)"
$foreignAlert = Invoke-Api POST '/api/v1/fraud-alerts' @{ customerId=$otherCustomer; amount=100001; newGeography=$false; eventsLastHour=1 } $bearer
Check 'X1-foreign-alert-body' ($foreignAlert.Status -eq 403) "HTTP $($foreignAlert.Status)"
$lowAlert = Invoke-Api POST '/api/v1/fraud-alerts' @{ customerId=$customerId; amount=100; newGeography=$false; eventsLastHour=1 } $bearer
Check 'F1-low-alert' ($lowAlert.Status -eq 200 -and $lowAlert.Body.severity -eq 'LOW') "HTTP $($lowAlert.Status), severity=$($lowAlert.Body.severity)"
$invalidAlert = Invoke-Api POST '/api/v1/fraud-alerts' @{ customerId=$customerId; amount=-1; newGeography=$false; eventsLastHour=-1 } $bearer
Check 'F1-invalid' ($invalidAlert.Status -eq 400) "HTTP $($invalidAlert.Status)"
$alerts = Invoke-Api GET "/api/v1/fraud-alerts?customerId=$customerId" $null $bearer
Check 'F2-list' ($alerts.Status -eq 200 -and @($alerts.Body).Count -gt 0) "HTTP $($alerts.Status), count=$(@($alerts.Body).Count)"

if ($accountId) {
    $transferKey = [guid]::NewGuid().ToString()
    $transferBody = @{ sourceAccountId=$accountId; destinationAccountReference='TEST-BENEFICIARY'; rail='IMPS'; amount=10.25 }
    $transferHeaders = $bearer.Clone(); $transferHeaders['Idempotency-Key'] = $transferKey
    $beforeTransfers = Db-Scalar 'transaction_ledger_db' "SELECT COUNT(*) FROM payment_transfers WHERE idempotency_key='$transferKey'"
    $transfer = Invoke-Api POST '/api/v1/transfers' $transferBody $transferHeaders
    $afterTransfers = Db-Scalar 'transaction_ledger_db' "SELECT COUNT(*) FROM payment_transfers WHERE idempotency_key='$transferKey'"
    $journalCount = Db-Scalar 'transaction_ledger_db' "SELECT COUNT(*) FROM journal_lines"
    Check 'C1-fail-closed' ($transfer.Status -eq 503 -and $beforeTransfers -eq $afterTransfers) "HTTP $($transfer.Status), transferRowsBefore=$beforeTransfers, after=$afterTransfers, journalLines=$journalCount"
    $negativeTransfer = Invoke-Api POST '/api/v1/transfers' @{ sourceAccountId=$accountId; destinationAccountReference='TEST-BENEFICIARY'; rail='IMPS'; amount=-1 } @{ Authorization=$bearer.Authorization; 'X-Customer-Id'=$customerId; 'Idempotency-Key'=[guid]::NewGuid().ToString() }
    Check 'C1-negative' ($negativeTransfer.Status -eq 400) "HTTP $($negativeTransfer.Status)"
    $missingKey = Invoke-Api POST '/api/v1/transfers' $transferBody $bearer
    Check 'C1-missing-key' ($missingKey.Status -eq 400) "HTTP $($missingKey.Status)"
    $freeze = Invoke-Api POST "/api/v1/accounts/$accountId/freeze" $null $bearer
    $frozenCount = Db-Scalar 'account_db' "SELECT COUNT(*) FROM accounts WHERE id=UUID_TO_BIN('$accountId') AND status='FROZEN'"
    Check 'B3-freeze' ($freeze.Status -eq 200 -and $freeze.Body.status -eq 'FROZEN' -and $frozenCount -eq '1') "HTTP $($freeze.Status), frozenRows=$frozenCount"
    $unknownFreeze = Invoke-Api POST "/api/v1/accounts/$([guid]::NewGuid())/freeze" $null $bearer
    Check 'B3-unknown' ($unknownFreeze.Status -eq 404) "HTTP $($unknownFreeze.Status)"
    $frozenTransfer = Invoke-Api POST '/api/v1/transfers' $transferBody @{ Authorization=$bearer.Authorization; 'X-Customer-Id'=$customerId; 'Idempotency-Key'=[guid]::NewGuid().ToString() }
    Check 'C1-frozen-fail-closed' ($frozenTransfer.Status -eq 503) "HTTP $($frozenTransfer.Status)"
}

$passedCount = @($script:results | Where-Object { $_ -match ' PASS ' }).Count
$failedCount = @($script:results | Where-Object { $_ -match ' FAIL ' }).Count
Write-Output "TOTAL $($script:results.Count) PASS $passedCount FAIL $failedCount"
if ($failedCount -gt 0) { exit 1 }
if (-not $SmokeOnly) {
    Write-Output 'ACCEPTANCE BLOCKED: money posting, valid MFA enrollment, durable fraud alerts, and transfer-driven cross-service events are not implemented.'
    exit 1
}
