param(
    [int]$BackendPort = 18080
)

$ErrorActionPreference = 'Stop'

$env:POSTGRES_DB = 'p2p_chat_alpha'
$env:POSTGRES_USER = 'p2p_chat_alpha'
$env:POSTGRES_PASSWORD = 'p2p-alpha-db-local-only'
$env:JWT_SECRET = [Convert]::ToBase64String(
    [Text.Encoding]::UTF8.GetBytes('p2p-alpha-jwt-local-only-32-bytes-minimum')
)
$env:LOCAL_DEV_AUTH_KEY = 'p2p-alpha-local-only'
$env:BACKEND_PORT = $BackendPort.ToString()
$env:POSTGRES_PORT = '5432'

docker compose up --build -d
if ($LASTEXITCODE -ne 0) { throw 'Failed to start alpha backend.' }

$deadline = (Get-Date).AddMinutes(2)
do {
    Start-Sleep -Seconds 2
    try {
        $health = Invoke-RestMethod "http://127.0.0.1:$BackendPort/actuator/health/readiness"
    } catch {
        $health = $null
    }
} while (($null -eq $health -or $health.status -ne 'UP') -and (Get-Date) -lt $deadline)

if ($null -eq $health -or $health.status -ne 'UP') {
    throw 'Alpha backend did not become ready.'
}
Write-Host "Alpha backend is ready at http://127.0.0.1:$BackendPort"
