[CmdletBinding()]
param(
    [string]$EnvFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'production.env'),

    [string]$ComposeFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'compose.production.yml'),

    [switch]$AllowLocalVerification
)

$ErrorActionPreference = 'Stop'

function Read-EnvironmentFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $values = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        if ($trimmed -notmatch '^([A-Z][A-Z0-9_]*)=(.*)$') {
            throw "Invalid production environment line. Expected NAME=value."
        }
        $name = $Matches[1]
        if ($values.ContainsKey($name)) { throw "Duplicate production environment key: $name" }
        $values[$name] = $Matches[2]
    }
    return $values
}

function Require-Value {
    param(
        [hashtable]$Values,
        [string]$Name
    )

    $value = [string]$Values[$Name]
    if ([string]::IsNullOrWhiteSpace($value)) { throw "Missing production environment value: $Name" }
    if ($value -match '(?i)replace-with|example\.com|change-me|placeholder') {
        throw "Production environment value is still a placeholder: $Name"
    }
    return $value
}

function Assert-Base64Key {
    param(
        [string]$Name,
        [string]$Value
    )

    try { $bytes = [Convert]::FromBase64String($Value) } catch { throw "$Name must be valid base64." }
    if ($bytes.Length -lt 32) { throw "$Name must contain at least 32 decoded bytes." }
}

$resolvedEnvFile = (Resolve-Path -LiteralPath $EnvFile -ErrorAction Stop).Path
$resolvedComposeFile = (Resolve-Path -LiteralPath $ComposeFile -ErrorAction Stop).Path
$values = Read-EnvironmentFile -Path $resolvedEnvFile

$publicHost = Require-Value -Values $values -Name 'PUBLIC_HOST'
$acmeEmail = Require-Value -Values $values -Name 'ACME_EMAIL'
$backendImage = Require-Value -Values $values -Name 'BACKEND_IMAGE'
$caddyImage = Require-Value -Values $values -Name 'CADDY_IMAGE'
$postgresImage = Require-Value -Values $values -Name 'POSTGRES_IMAGE'
$postgresDatabase = Require-Value -Values $values -Name 'POSTGRES_DB'
$postgresUser = Require-Value -Values $values -Name 'POSTGRES_USER'
$postgresPassword = Require-Value -Values $values -Name 'POSTGRES_PASSWORD'
$jwtSecret = Require-Value -Values $values -Name 'JWT_SECRET'
$pushKeys = Require-Value -Values $values -Name 'PUSH_TOKEN_ENCRYPTION_KEYS'
$allowedOrigins = Require-Value -Values $values -Name 'WEBSOCKET_ALLOWED_ORIGINS'
$logMaxSize = if ([string]::IsNullOrWhiteSpace([string]$values['LOG_MAX_SIZE'])) { '10m' } else { [string]$values['LOG_MAX_SIZE'] }
$logMaxFilesText = if ([string]::IsNullOrWhiteSpace([string]$values['LOG_MAX_FILES'])) { '5' } else { [string]$values['LOG_MAX_FILES'] }

if ($AllowLocalVerification) {
    if ($publicHost -ne 'localhost') { throw 'Local verification requires PUBLIC_HOST=localhost.' }
    $expectedHttpPort = [int](Require-Value -Values $values -Name 'HTTP_PORT')
    $expectedHttpsPort = [int](Require-Value -Values $values -Name 'HTTPS_PORT')
} elseif ($publicHost -notmatch '^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$') {
    throw 'PUBLIC_HOST must be a valid public DNS hostname.'
} else {
    $expectedHttpPort = 80
    $expectedHttpsPort = 443
}
if ($expectedHttpPort -lt 1 -or $expectedHttpPort -gt 65535) { throw 'HTTP_PORT is invalid.' }
if ($expectedHttpsPort -lt 1 -or $expectedHttpsPort -gt 65535) { throw 'HTTPS_PORT is invalid.' }
if ($expectedHttpPort -eq $expectedHttpsPort) { throw 'HTTP_PORT and HTTPS_PORT must differ.' }
if ($acmeEmail -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') { throw 'ACME_EMAIL is invalid.' }
if ($logMaxSize -notmatch '^[1-9][0-9]{0,3}[kKmMgG]$') { throw 'LOG_MAX_SIZE must be 1-9999 followed by k, m, or g.' }
$logMaxFiles = 0
if (-not [int]::TryParse($logMaxFilesText, [ref]$logMaxFiles) -or $logMaxFiles -lt 2 -or $logMaxFiles -gt 20) {
    throw 'LOG_MAX_FILES must be an integer from 2 through 20.'
}

$digestPattern = '@sha256:[0-9a-f]{64}$'
if (-not $AllowLocalVerification) {
    foreach ($entry in @{
        BACKEND_IMAGE = $backendImage
        CADDY_IMAGE = $caddyImage
        POSTGRES_IMAGE = $postgresImage
    }.GetEnumerator()) {
        if ($entry.Value -notmatch $digestPattern) {
            throw "$($entry.Key) must use a registry-verified sha256 digest."
        }
    }
}

if ($postgresDatabase -notmatch '^[a-zA-Z][a-zA-Z0-9_]{0,62}$') { throw 'POSTGRES_DB is invalid.' }
if ($postgresUser -notmatch '^[a-zA-Z][a-zA-Z0-9_]{0,62}$') { throw 'POSTGRES_USER is invalid.' }
if ($postgresPassword.Length -lt 20) { throw 'POSTGRES_PASSWORD must contain at least 20 characters.' }
Assert-Base64Key -Name 'JWT_SECRET' -Value $jwtSecret

foreach ($entry in $pushKeys.Split(',')) {
    if ($entry -notmatch '^([A-Za-z0-9._-]+)=(.+)$') {
        throw 'PUSH_TOKEN_ENCRYPTION_KEYS must use key-id=base64-key entries.'
    }
    Assert-Base64Key -Name "PUSH_TOKEN_ENCRYPTION_KEYS/$($Matches[1])" -Value $Matches[2]
}

$origins = @($allowedOrigins.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($origins.Count -eq 0 -or $origins -contains '*') { throw 'WEBSOCKET_ALLOWED_ORIGINS cannot be empty or wildcard.' }
foreach ($origin in $origins) {
    if ($origin -notmatch '^https://[^/]+$') { throw 'Every WebSocket origin must use an exact HTTPS origin.' }
}
$expectedOrigin = "https://$publicHost"
if ($origins -notcontains $expectedOrigin) { throw "WEBSOCKET_ALLOWED_ORIGINS must include $expectedOrigin." }

$dockerPath = (Get-Command docker -ErrorAction Stop).Source
& $dockerPath compose --env-file $resolvedEnvFile -f $resolvedComposeFile config --quiet
if ($LASTEXITCODE -ne 0) { throw 'Docker Compose rejected the production configuration.' }
$configJson = & $dockerPath compose --env-file $resolvedEnvFile -f $resolvedComposeFile config --format json
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect the rendered production configuration.' }
$config = $configJson | ConvertFrom-Json -Depth 40

foreach ($serviceName in @('proxy', 'backend', 'postgres')) {
    if ($null -eq $config.services.$serviceName) { throw "Missing production service: $serviceName" }
    $logging = $config.services.$serviceName.logging
    if ($logging.driver -ne 'json-file' -or $logging.options.'max-size' -cne $logMaxSize.ToLowerInvariant() -or
        [string]$logging.options.'max-file' -cne [string]$logMaxFiles) {
        throw "Production service $serviceName must use the configured bounded json-file logging policy."
    }
}
$backendPublishedPorts = @(
    $config.services.backend.ports |
        Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string]$_.published) }
)
$postgresPublishedPorts = @(
    $config.services.postgres.ports |
        Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string]$_.published) }
)
if ($backendPublishedPorts.Count -ne 0) { throw 'Backend must not publish a host port.' }
if ($postgresPublishedPorts.Count -ne 0) { throw 'PostgreSQL must not publish a host port.' }
if ($config.services.backend.environment.SPRING_PROFILES_ACTIVE -ne 'prod') {
    throw 'Backend must use the prod Spring profile.'
}
if ($null -ne $config.services.backend.environment.LOCAL_DEV_AUTH_KEY) {
    throw 'Production backend must not receive LOCAL_DEV_AUTH_KEY.'
}
if (-not $config.networks.data.internal) { throw 'The production data network must be internal.' }
$publishedPorts = @($config.services.proxy.ports | ForEach-Object { [int]$_.published })
if ($publishedPorts -notcontains $expectedHttpPort -or $publishedPorts -notcontains $expectedHttpsPort) {
    throw "TLS proxy must publish ports $expectedHttpPort and $expectedHttpsPort."
}

[pscustomobject]@{
    status = 'PASS'
    publicHost = $publicHost
    backendImage = $backendImage
    caddyImage = $caddyImage
    postgresImage = $postgresImage
    backendPublishesHostPort = $false
    postgresPublishesHostPort = $false
    dataNetworkInternal = $true
    websocketOrigins = $origins
    httpPort = $expectedHttpPort
    httpsPort = $expectedHttpsPort
    logMaxSize = $logMaxSize.ToLowerInvariant()
    logMaxFiles = $logMaxFiles
    localVerification = [bool]$AllowLocalVerification
} | ConvertTo-Json -Depth 5
