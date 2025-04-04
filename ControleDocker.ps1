$response = Invoke-WebRequest -Uri http://127.0.0.1:2375/info
$data = $response.Content | ConvertFrom-Json

Write-Host "Containers : $($data.Containers)" -ForegroundColor Green
Write-Host "ContainersRunning  : $($data.ContainersRunning )" -ForegroundColor Green
