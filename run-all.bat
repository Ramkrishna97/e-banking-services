@echo off
setlocal EnableExtensions
set "ROOT=%~dp0"
set "COMPOSE=%ROOT%docker\docker-compose.yml"
set "WEB=%ROOT%web"
set "NO_PAUSE=0"
set "NO_BROWSER=0"
if /I "%~1"=="--check" (set "NO_PAUSE=1"&set "NO_BROWSER=1")

where docker >nul 2>nul || (
  echo [ERROR] Docker Desktop CLI is required and was not found on PATH.
  goto failed
)
where node >nul 2>nul || (
  echo [ERROR] Node.js is required for the React client and was not found on PATH.
  goto failed
)

docker info >nul 2>nul
if errorlevel 1 goto start_docker
goto docker_ready

:start_docker
set "DOCKER_DESKTOP=%LOCALAPPDATA%\Programs\DockerDesktop\Docker Desktop.exe"
if not exist "%DOCKER_DESKTOP%" set "DOCKER_DESKTOP=C:\Program Files\Docker\Docker\Docker Desktop.exe"
if not exist "%DOCKER_DESKTOP%" (
  echo [ERROR] Docker Desktop is installed but its engine is not running.
  echo Start Docker Desktop manually, wait for it to become ready, then run this script again.
  goto failed
)
echo Starting Docker Desktop...
start "Docker Desktop" "%DOCKER_DESKTOP%"
set /a ATTEMPTS=0
:wait_for_docker
rem Use ping rather than timeout: timeout fails when launched without console input.
ping 127.0.0.1 -n 6 >nul
docker info >nul 2>nul
if not errorlevel 1 goto docker_ready
set /a ATTEMPTS+=1
if %ATTEMPTS% GEQ 24 (
  echo [ERROR] Docker Desktop did not become ready within two minutes.
  goto failed
)
goto wait_for_docker
:docker_ready

echo.
echo === Starting E-Banking Platform ===
echo Building Spring Boot services in one Gradle invocation...
pushd "%ROOT%"
call gradlew.bat :platform:config-server:bootJar :platform:discovery-server:bootJar :platform:api-gateway:bootJar :services:auth-kyc-service:bootJar :services:account-service:bootJar :services:fund-transfer-service:bootJar :services:loan-service:bootJar :services:card-service:bootJar :services:notification-fraud-service:bootJar --no-daemon --max-workers=2
if errorlevel 1 (
  popd
  echo [ERROR] Java build failed. Review the Gradle error above.
  goto failed
)
popd
echo Building images and starting MySQL, Redis, Kafka, Spring Cloud, and banking services...
docker compose -f "%COMPOSE%" build --parallel=false
if errorlevel 1 (
  echo [ERROR] Docker image build failed.
  goto failed
)
docker compose -f "%COMPOSE%" up -d --no-build
if errorlevel 1 (
  echo [ERROR] The backend stack did not start. Inspect logs with:
  echo docker compose -f "%COMPOSE%" logs --tail=100
  goto failed
)
echo Waiting for API Gateway health...
set /a HEALTH_ATTEMPTS=0
:wait_for_gateway
curl.exe --silent --fail http://localhost:8080/actuator/health >nul 2>nul
if not errorlevel 1 goto gateway_ready
set /a HEALTH_ATTEMPTS+=1
if %HEALTH_ATTEMPTS% GEQ 24 (
  echo [ERROR] API Gateway did not become healthy within two minutes.
  docker compose -f "%COMPOSE%" ps -a
  docker compose -f "%COMPOSE%" logs --tail=50 api-gateway
  goto failed
)
ping 127.0.0.1 -n 6 >nul
goto wait_for_gateway
:gateway_ready
for /f %%I in ('docker compose -f "%COMPOSE%" ps --status exited -q') do (
  echo [ERROR] A required service exited during startup.
  docker compose -f "%COMPOSE%" ps -a
  goto failed
)

if not exist "%WEB%\node_modules" (
  echo Installing frontend dependencies...
  pushd "%WEB%"
  call npm.cmd install
  if errorlevel 1 (
    popd
    echo [ERROR] Frontend dependency installation failed.
    goto failed
  )
  popd
)

curl.exe --silent --fail http://localhost:5173/ >nul 2>nul
if errorlevel 1 (
  echo Launching React development server in a separate window...
  start "E-Banking Web" /D "%WEB%" cmd.exe /k npm.cmd run dev -- --host 127.0.0.1 --strictPort
) else (
  echo React development server is already running on port 5173.
)
echo Waiting for React UI...
set /a UI_ATTEMPTS=0
:wait_for_ui
curl.exe --silent --fail http://localhost:5173/ >nul 2>nul
if not errorlevel 1 goto ui_ready
set /a UI_ATTEMPTS+=1
if %UI_ATTEMPTS% GEQ 24 (
  echo [ERROR] React UI did not become available at http://localhost:5173/ within two minutes.
  goto failed
)
ping 127.0.0.1 -n 6 >nul
goto wait_for_ui
:ui_ready

echo.
echo Stack started.
echo Gateway:        http://localhost:8080
echo Discovery:      http://localhost:8761
echo Config Server:  http://localhost:8888
echo Web client:     http://localhost:5173
echo.
echo To stop the backend stack, run: docker compose -f "%COMPOSE%" down
if "%NO_BROWSER%"=="0" start "" "http://localhost:5173/"
if "%NO_PAUSE%"=="0" pause
endlocal
exit /b 0

:failed
echo.
echo Startup stopped. Review the error above before closing this window.
if "%NO_PAUSE%"=="0" pause
endlocal
exit /b 1
