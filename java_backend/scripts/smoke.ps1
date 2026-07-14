[CmdletBinding()]
param(
    [ValidateRange(30, 600)]
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'

function Get-FreeTcpPort {
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    try {
        $listener.Start()
        return ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    } finally {
        $listener.Stop()
    }
}

function New-RandomBase64Key {
    $bytes = [byte[]]::new(32)
    [Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return [Convert]::ToBase64String($bytes)
}

$dockerPath = (Get-Command docker -ErrorAction Stop).Source
$environmentNames = @(
    'BACKEND_PORT',
    'COMPOSE_PROJECT_NAME',
    'FCM_ENABLED',
    'JWT_SECRET',
    'LOCAL_DEV_AUTH_KEY',
    'POSTGRES_DB',
    'POSTGRES_PASSWORD',
    'POSTGRES_PORT',
    'POSTGRES_USER',
    'PUSH_DELIVERY_ENABLED',
    'PUSH_TOKEN_ENCRYPTION_KEYS'
)
$originalEnvironment = @{}
foreach ($name in $environmentNames) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

$backendPort = Get-FreeTcpPort
do { $postgresPort = Get-FreeTcpPort } while ($postgresPort -eq $backendPort)
$smokeKey = New-RandomBase64Key
$smokeEnvironment = @{
    BACKEND_PORT = [string]$backendPort
    COMPOSE_PROJECT_NAME = "p2p-chat-smoke-$PID-$([Guid]::NewGuid().ToString('N').Substring(0, 8))"
    FCM_ENABLED = 'false'
    JWT_SECRET = New-RandomBase64Key
    LOCAL_DEV_AUTH_KEY = [Guid]::NewGuid().ToString('N')
    POSTGRES_DB = 'p2p_chat_smoke'
    POSTGRES_PASSWORD = "smoke-$([Guid]::NewGuid().ToString('N'))"
    POSTGRES_PORT = [string]$postgresPort
    POSTGRES_USER = 'p2p_chat_smoke'
    PUSH_DELIVERY_ENABLED = 'false'
    PUSH_TOKEN_ENCRYPTION_KEYS = "smoke-v1=$smokeKey"
}

$primaryError = $null
$cleanupExitCode = 0
$result = $null
try {
    foreach ($entry in $smokeEnvironment.GetEnumerator()) {
        [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'Process')
    }

    & $dockerPath compose up --build -d
    if ($LASTEXITCODE -ne 0) { throw 'Docker Compose could not start the isolated smoke environment.' }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $healthy = $false
    do {
        Start-Sleep -Seconds 3
        try {
            $health = Invoke-RestMethod "http://localhost:$backendPort/actuator/health/readiness"
            $healthy = $health.status -eq 'UP'
        } catch {
            $healthy = $false
        }
    } while (-not $healthy -and (Get-Date) -lt $deadline)
    if (-not $healthy) { throw 'Backend did not become healthy before the smoke timeout.' }

    $backendContainerId = ((& $dockerPath compose ps -q backend) -join "`n").Trim()
    $postgresContainerId = ((& $dockerPath compose ps -q postgres) -join "`n").Trim()
    if ($backendContainerId -notmatch '^[0-9a-f]{12,64}$' -or $postgresContainerId -notmatch '^[0-9a-f]{12,64}$') {
        throw 'Unable to resolve isolated smoke container IDs.'
    }

    $backendUser = ((& $dockerPath exec $backendContainerId id -un) -join "`n").Trim()
    if ($LASTEXITCODE -ne 0 -or $backendUser -ne 'app') { throw 'Backend container is not running as app.' }

    $flywayVersions = ((& $dockerPath exec $postgresContainerId psql `
        --username=$env:POSTGRES_USER `
        --dbname=$env:POSTGRES_DB `
        --tuples-only `
        --no-align `
        --command="SELECT string_agg(version, ',' ORDER BY installed_rank) FROM flyway_schema_history WHERE success") -join "`n").Trim()
    if ($LASTEXITCODE -ne 0 -or $flywayVersions -ne '1,2,3,4,5,6,7,8,9') {
        throw "Unexpected Flyway versions: $flywayVersions"
    }

    $publicTableCountText = ((& $dockerPath exec $postgresContainerId psql `
        --username=$env:POSTGRES_USER `
        --dbname=$env:POSTGRES_DB `
        --tuples-only `
        --no-align `
        --command="SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'") -join "`n").Trim()
    if ($LASTEXITCODE -ne 0 -or $publicTableCountText -notmatch '^\d+$' -or [int]$publicTableCountText -ne 10) {
        throw "Unexpected public table count: $publicTableCountText"
    }

    $result = [pscustomobject]@{
        status = 'PASS'
        backendUser = $backendUser
        flywayVersions = $flywayVersions
        publicTableCount = [int]$publicTableCountText
    }
} catch {
    $primaryError = $_
    Write-Warning 'Container smoke failed; printing the last 200 bounded log lines before cleanup.'
    & $dockerPath compose logs --no-color --tail 200 2>&1 | Write-Warning
} finally {
    & $dockerPath compose down --volumes --remove-orphans
    $cleanupExitCode = $LASTEXITCODE
    foreach ($name in $environmentNames) {
        [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name], 'Process')
    }
}

if ($null -ne $primaryError) { throw $primaryError }
if ($cleanupExitCode -ne 0) { throw 'Docker Compose smoke cleanup failed.' }
$result | ConvertTo-Json -Depth 5
