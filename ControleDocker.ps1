# Script contrôle sur Docker (Docker Desktop + wsl2)
# Voir config dans README.md
# SD 2025



$response = Invoke-WebRequest -Uri http://127.0.0.1:2375/info
$data = $response.Content | ConvertFrom-Json
Write-Host "Containers : $($data.Containers)" -ForegroundColor Green
Write-Host "ContainersRunning  : $($data.ContainersRunning )" -ForegroundColor Green

$response = Invoke-WebRequest -Uri http://127.0.0.1:2375/containers/json
$data = $response.Content | ConvertFrom-Json
Write-Host "Names : $($data.Names)" -ForegroundColor Green
Write-Host "State  : $($data.State )" -ForegroundColor Green


docker -H tcp://192.168.0.11:2375 exec -it mqtt_broker sh -c "cat /proc/1/comm" 
