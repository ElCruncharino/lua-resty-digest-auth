@echo off
REM Test script for lua-resty-digest-auth (Windows)
REM This script tests the module running in WSL

echo 🧪 Testing lua-resty-digest-auth module from Windows...
echo ===================================================

REM Check if WSL is available
wsl --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ WSL is not available. Please install WSL first.
    echo Visit: https://docs.microsoft.com/en-us/windows/wsl/install
    pause
    exit /b 1
)

REM Check if the test server is running
echo 📡 Checking if test server is running...
wsl curl -s -o /dev/null -w "%%{http_code}" http://localhost:8080/health > temp_status.txt
set /p status=<temp_status.txt
del temp_status.txt

if "%status%"=="200" (
    echo ✅ Test server is running
) else (
    echo ⚠️  Test server is not running. Starting it now...
    wsl start_test_server
    timeout /t 3 /nobreak >nul
)

echo.
echo 🧪 Running tests...
echo ===================

REM Test public endpoint
echo 1. Testing public endpoint...
wsl curl -s -o /dev/null -w "Status: %%{http_code}\n" http://localhost:8080/

REM Test protected endpoint (should get 401)
echo.
echo 2. Testing protected endpoint (expecting 401)...
wsl curl -s -o /dev/null -w "Status: %%{http_code}\n" http://localhost:8080/protected/

REM Test with valid credentials
echo.
echo 3. Testing with valid credentials (alice:password123)...
wsl curl -s -u "alice:password123" -w "Status: %%{http_code}\n" http://localhost:8080/protected/

REM Test with invalid credentials
echo.
echo 4. Testing with invalid credentials...
wsl curl -s -u "alice:wrongpassword" -w "Status: %%{http_code}\n" http://localhost:8080/protected/

REM Test API endpoint
echo.
echo 5. Testing API endpoint with valid credentials...
wsl curl -s -u "bob:secret456" -w "Status: %%{http_code}\n" http://localhost:8080/api/

REM Test admin endpoint
echo.
echo 6. Testing admin endpoint with valid credentials...
wsl curl -s -u "admin:adminpass" -w "Status: %%{http_code}\n" http://localhost:8080/admin/

REM Test health endpoint
echo.
echo 7. Testing health endpoint...
wsl curl -s -w "Status: %%{http_code}\n" http://localhost:8080/health

echo.
echo ✅ Testing complete!
echo.
echo 📋 Manual testing commands:
echo   wsl curl -u alice:password123 http://localhost:8080/protected/
echo   wsl curl -u bob:secret456 http://localhost:8080/api/
echo   wsl curl -u admin:adminpass http://localhost:8080/admin/
echo.
echo 🔧 WSL Management commands:
echo   wsl start_test_server  - Start the test server
echo   wsl stop_test_server   - Stop the test server
echo   wsl restart_test_server - Restart the test server
echo   wsl test_digest_auth   - Run automated tests in WSL
echo.
echo 🌐 Test URLs (accessible from Windows):
echo   http://localhost:8080/ - Public content
echo   http://localhost:8080/protected/ - Protected content
echo   http://localhost:8080/api/ - API endpoint
echo   http://localhost:8080/admin/ - Admin area
echo   http://localhost:8080/health - Health check
echo.
pause 