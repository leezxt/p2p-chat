$ErrorActionPreference = 'Stop'

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker CLI is required for the container smoke test.'
}

if (-not $env:PUSH_TOKEN_ENCRYPTION_KEYS) {
    $env:PUSH_TOKEN_ENCRYPTION_KEYS = 'smoke-v1=' + [Convert]::ToBase64String([byte[]](0..31))
}

docker compose up --build -d
try {
    $deadline = (Get-Date).AddMinutes(3)
    do {
        Start-Sleep -Seconds 3
        try {
            $health = Invoke-RestMethod 'http://localhost:8080/actuator/health/readiness'
            if ($health.status -eq 'UP') {
                Write-Host 'Backend container smoke test passed.'
                exit 0
            }
        } catch {
            if ((Get-Date) -ge $deadline) { throw }
        }
    } while ((Get-Date) -lt $deadline)
    throw 'Backend did not become healthy before the timeout.'
} finally {
    docker compose down
}
