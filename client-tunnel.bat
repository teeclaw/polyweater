@echo off
REM PolyWeather SSH Tunnel for Windows
REM Requires OpenSSH client or PuTTY

set SERVER_IP=104.154.72.5
set SERVER_USER=phan_harry
set DASHBOARD_PORT=13000
set API_PORT=18080
set MONITORING_PORT=19090

echo Creating SSH tunnels to PolyWeather dashboard...
echo Server: %SERVER_USER%@%SERVER_IP%
echo.
echo Local endpoints:
echo   Dashboard:  https://localhost:%DASHBOARD_PORT%
echo   API:        https://localhost:%API_PORT%
echo   Monitoring: http://localhost:%MONITORING_PORT%
echo.
echo Press Ctrl+C to close tunnels

ssh -L %DASHBOARD_PORT%:localhost:443 -L %API_PORT%:localhost:8080 -L %MONITORING_PORT%:localhost:9090 -N %SERVER_USER%@%SERVER_IP%
