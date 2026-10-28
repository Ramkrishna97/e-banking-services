param([Alias('--check')][switch]$Check, [switch]$Stop)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$stateDirectory = Join-Path $root '.run'
$stateFile = Join-Path $stateDirectory 'processes.json'
$web = Join-Path $root 'web'
$started = @()

function Get-LiveProcess($entry) {
    $process = Get-Process -Id $entry.Id -ErrorAction SilentlyContinue
    if ($process -and $process.StartTime.ToUniversalTime().ToString('o') -eq $entry.StartedAt) { return $process }
    return $null
}

function Save-State {
    if (-not (Test-Path $stateDirectory)) { New-Item -ItemType Directory -Path $stateDirectory | Out-Null }
    ConvertTo-Json -InputObject @($started) -Depth 3 | Set-Content -LiteralPath $stateFile
}

function Stop-LocalProcesses {
    if (-not (Test-Path $stateFile)) { Write-Host 'No local E-Banking processes are recorded.'; return }
    $entries = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
    [array]::Reverse($entries)
    foreach ($entry in $entries) {
        $process = Get-LiveProcess $entry
        if ($process) {
            & taskkill.exe /PID $process.Id /T /F *> $null
            Write-Host "Stopped $($entry.Name) (PID $($process.Id))."
        }
    }
    Remove-Item -LiteralPath $stateFile
}

function Start-ManagedProcess([string]$Name, [string]$Executable, [string[]]$Arguments, [string]$WorkingDirectory) {
    $output = Join-Path $stateDirectory "$Name.out.log"
    $errors = Join-Path $stateDirectory "$Name.err.log"
    $process = Start-Process -FilePath $Executable -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -WindowStyle Hidden -RedirectStandardOutput $output -RedirectStandardError $errors -PassThru
    $script:started += [pscustomobject]@{ Name = $Name; Id = $process.Id; StartedAt = $process.StartTime.ToUniversalTime().ToString('o') }
    Save-State
    Write-Host "Started $Name (PID $($process.Id))."
}

function Wait-ForUrl([string]$Url, [string]$Name, [int]$Seconds) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        $entry = $script:started | Where-Object Name -eq $Name | Select-Object -First 1
        if ($entry -and -not (Get-LiveProcess $entry)) { throw "$Name exited during startup. See .run/$Name.err.log and .run/$Name.out.log." }
        try {
            $response = Invoke-WebRequest $Url -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -eq 200) { return }
        } catch { }
        Start-Sleep -Seconds 2
    }
    throw "Timed out waiting for $Name at $Url. See .run/$Name.err.log and .run/$Name.out.log."
}

function Wait-ForAuthRoute([int]$Seconds) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        try {
            Invoke-WebRequest 'http://127.0.0.1:8080/api/v1/auth/register' -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing -TimeoutSec 3 | Out-Null
        } catch {
            if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 400) { return }
        }
        Start-Sleep -Seconds 2
    }
    throw 'Gateway could not route to the auth service. See .run/api-gateway.out.log.'
}

try {
    if ($Stop) { Stop-LocalProcesses; exit 0 }
    if (Test-Path $stateFile) {
        $existing = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
        if ($existing | Where-Object { Get-LiveProcess $_ }) { throw 'E-Banking is already running. Use stop-all.bat before starting it again.' }
        Remove-Item -LiteralPath $stateFile
    }
    foreach ($name in @('java.exe', 'javac.exe', 'node.exe', 'npm.cmd')) {
        if (-not (Get-Command $name -ErrorAction SilentlyContinue)) { throw "$name is required on PATH. Install JDK 17+ and Node.js 22+." }
    }
    foreach ($port in @(8761, 8080, 8081, 8082, 8083, 8084, 8085, 8086, 5173)) {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)
        try {
            $listener.Start()
        } catch [System.Management.Automation.MethodInvocationException] {
            throw "Port $port is already in use. Stop the process using it before starting E-Banking."
        } finally { $listener.Stop() }
    }

    Write-Host 'Building Spring Boot services with Gradle...'
    Push-Location $root
    try {
        & (Join-Path $root 'gradlew.bat') ':platform:discovery-server:bootJar' ':platform:api-gateway:bootJar' ':services:auth-kyc-service:bootJar' ':services:account-service:bootJar' ':services:fund-transfer-service:bootJar' ':services:loan-service:bootJar' ':services:card-service:bootJar' ':services:notification-fraud-service:bootJar' --no-daemon --max-workers=2
        if ($LASTEXITCODE -ne 0) { throw 'Gradle build failed.' }
    } finally { Pop-Location }

    if (-not (Test-Path (Join-Path $web 'node_modules/vite/bin/vite.js'))) {
        Write-Host 'Installing frontend dependencies...'
        Push-Location $web
        try {
            & npm.cmd ci
            if ($LASTEXITCODE -ne 0) { throw 'Frontend dependency installation failed.' }
        } finally { Pop-Location }
    }
    if (-not (Test-Path $stateDirectory)) { New-Item -ItemType Directory -Path $stateDirectory | Out-Null }
    if (-not (Test-Path (Join-Path $root 'data'))) { New-Item -ItemType Directory -Path (Join-Path $root 'data') | Out-Null }
    $java = (Get-Command java.exe).Source
    $node = (Get-Command node.exe).Source
    $modules = @(
        'platform/discovery-server',
        'services/auth-kyc-service',
        'services/account-service',
        'services/fund-transfer-service',
        'services/loan-service',
        'services/card-service',
        'services/notification-fraud-service',
        'platform/api-gateway'
    )
    foreach ($module in $modules) {
        $name = Split-Path $module -Leaf
        $jar = Get-ChildItem -LiteralPath (Join-Path $root "$module/build/libs") -Filter '*-SNAPSHOT.jar' | Select-Object -First 1
        if (-not $jar) { throw "JAR missing for $name." }
        Start-ManagedProcess $name $java @('-jar', ('"' + $jar.FullName + '"'), '--eureka.instance.prefer-ip-address=true', '--eureka.instance.ip-address=127.0.0.1') $root
        if ($name -eq 'discovery-server') { Wait-ForUrl 'http://127.0.0.1:8761/actuator/health' $name 120 }
    }
    Wait-ForUrl 'http://127.0.0.1:8080/actuator/health' 'api-gateway' 180
    foreach ($name in @('AUTH-KYC-SERVICE', 'ACCOUNT-SERVICE', 'FUND-TRANSFER-SERVICE', 'LOAN-SERVICE', 'CARD-SERVICE', 'NOTIFICATION-FRAUD-SERVICE')) {
        Wait-ForUrl "http://127.0.0.1:8761/eureka/apps/$name" 'discovery-server' 120
    }
    Wait-ForAuthRoute 90
    Start-ManagedProcess 'web' $node @('node_modules/vite/bin/vite.js', '--host', '127.0.0.1', '--strictPort') $web
    Wait-ForUrl 'http://127.0.0.1:5173/' 'web' 60
    Write-Host 'E-Banking is ready at http://127.0.0.1:5173/'
    Write-Host 'Use stop-all.bat to stop it. H2 data remains in data/.'
    if (-not $Check) { Start-Process 'http://127.0.0.1:5173/' }
} catch {
    Write-Host "Startup failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($started.Count -gt 0) { Stop-LocalProcesses }
    exit 1
}
