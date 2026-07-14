[CmdletBinding()]
param(
    [string]$EnvFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'production.env'),

    [ValidateRange(1, 60)]
    [int]$TimeoutSeconds = 10,

    [switch]$AllowLocalVerification
)

$ErrorActionPreference = 'Stop'
$startedAt = (Get-Date).ToUniversalTime()
$checks = [ordered]@{
    httpRedirect = $false
    readiness = $false
    securityHeaders = $false
    websocketUpgrade = $false
}
$failedCheck = 'configuration'
$httpClient = $null

function Read-EnvironmentFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $values = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        if ($trimmed -notmatch '^([A-Z][A-Z0-9_]*)=(.*)$') {
            throw 'Invalid production environment line. Expected NAME=value.'
        }
        if ($values.ContainsKey($Matches[1])) { throw "Duplicate production environment key: $($Matches[1])" }
        $values[$Matches[1]] = $Matches[2]
    }
    return $values
}

function Get-RequiredValue {
    param([hashtable]$Values, [string]$Name)

    $value = [string]$Values[$Name]
    if ([string]::IsNullOrWhiteSpace($value)) { throw "Missing production environment value: $Name" }
    return $value
}

try {
    $resolvedEnvFile = (Resolve-Path -LiteralPath $EnvFile -ErrorAction Stop).Path
    $values = Read-EnvironmentFile -Path $resolvedEnvFile
    $publicHost = Get-RequiredValue -Values $values -Name 'PUBLIC_HOST'
    $allowedOrigins = @(Get-RequiredValue -Values $values -Name 'WEBSOCKET_ALLOWED_ORIGINS' -split ',' |
        ForEach-Object { $_.Trim() } | Where-Object { $_ })

    if ($AllowLocalVerification) {
        if ($publicHost -ne 'localhost') { throw 'Local verification requires PUBLIC_HOST=localhost.' }
        $httpPort = [int](Get-RequiredValue -Values $values -Name 'HTTP_PORT')
        $httpsPort = [int](Get-RequiredValue -Values $values -Name 'HTTPS_PORT')
    } else {
        if ($publicHost -notmatch '^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$') {
            throw 'PUBLIC_HOST must be a valid public DNS hostname.'
        }
        $httpPort = 80
        $httpsPort = 443
    }
    if ($httpPort -lt 1 -or $httpPort -gt 65535 -or $httpsPort -lt 1 -or $httpsPort -gt 65535) {
        throw 'Configured monitor port is invalid.'
    }

    $expectedOrigin = "https://$publicHost"
    if ($allowedOrigins -notcontains $expectedOrigin) {
        throw "WEBSOCKET_ALLOWED_ORIGINS must include $expectedOrigin."
    }
    $httpAuthority = if ($httpPort -eq 80) { $publicHost } else { "${publicHost}:$httpPort" }
    $httpsAuthority = if ($httpsPort -eq 443) { $publicHost } else { "${publicHost}:$httpsPort" }
    $httpUri = [Uri]"http://$httpAuthority/actuator/health/readiness"
    $httpsUri = [Uri]"https://$httpsAuthority/actuator/health/readiness"
    $webSocketProbeUri = [Uri]"https://$httpsAuthority/ws/signaling"

    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    if ($AllowLocalVerification) {
        $handler.ServerCertificateCustomValidationCallback =
            [System.Net.Http.HttpClientHandler]::DangerousAcceptAnyServerCertificateValidator
    }
    $httpClient = [System.Net.Http.HttpClient]::new($handler)
    $httpClient.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)

    $failedCheck = 'httpRedirect'
    $redirectResponse = $httpClient.GetAsync($httpUri).GetAwaiter().GetResult()
    try {
        if ([int]$redirectResponse.StatusCode -notin @(301, 308) -or $redirectResponse.Headers.Location.Scheme -ne 'https') {
            throw "HTTP endpoint returned $([int]$redirectResponse.StatusCode) instead of an HTTPS redirect."
        }
        $checks.httpRedirect = $true
    } finally {
        $redirectResponse.Dispose()
    }

    $failedCheck = 'readiness'
    $readinessResponse = $httpClient.GetAsync($httpsUri).GetAwaiter().GetResult()
    try {
        $readinessBody = $readinessResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        if (-not $readinessResponse.IsSuccessStatusCode) {
            throw "Readiness endpoint returned HTTP $([int]$readinessResponse.StatusCode)."
        }
        $readiness = $readinessBody | ConvertFrom-Json -Depth 5
        if ($readiness.status -ne 'UP') { throw 'Readiness endpoint did not report UP.' }
        $checks.readiness = $true

        $failedCheck = 'securityHeaders'
        $hsts = [string]($readinessResponse.Headers.GetValues('Strict-Transport-Security') -join ',')
        $nosniff = [string]($readinessResponse.Headers.GetValues('X-Content-Type-Options') -join ',')
        if ($hsts -notmatch 'max-age=31536000' -or $nosniff -cne 'nosniff' -or $readinessResponse.Headers.Server.Count -ne 0) {
            throw 'HTTPS response is missing required security headers or exposes the Server header.'
        }
        $checks.securityHeaders = $true
    } finally {
        $readinessResponse.Dispose()
    }

    $failedCheck = 'websocketUpgrade'
    $curlPath = (Get-Command curl.exe -ErrorAction Stop).Source
    $webSocketKey = [Convert]::ToBase64String([Guid]::NewGuid().ToByteArray())
    $webSocketTimeoutSeconds = [Math]::Min($TimeoutSeconds, 3)
    $curlArguments = @(
        '--silent', '--show-error', '--include', '--no-buffer', '--http1.1',
        '--max-time', [string]$webSocketTimeoutSeconds,
        '--header', 'Connection: Upgrade',
        '--header', 'Upgrade: websocket',
        '--header', 'Sec-WebSocket-Version: 13',
        '--header', "Sec-WebSocket-Key: $webSocketKey",
        '--header', "Origin: $expectedOrigin"
    )
    if ($AllowLocalVerification) { $curlArguments += '--insecure' }
    $curlArguments += $webSocketProbeUri.AbsoluteUri
    $upgradeOutput = & $curlPath @curlArguments 2>&1
    $upgradeText = $upgradeOutput -join "`n"
    if ($upgradeText -notmatch '(?im)^HTTP/\S+ 101(?:\s|$)') {
        throw "WebSocket endpoint did not return 101 Switching Protocols (curl exit $LASTEXITCODE)."
    }
    $checks.websocketUpgrade = $true

    [pscustomobject]@{
        status = 'PASS'
        checkedAt = $startedAt.ToString('o')
        durationMs = [math]::Round(((Get-Date).ToUniversalTime() - $startedAt).TotalMilliseconds)
        endpoint = "https://$httpsAuthority"
        checks = $checks
        localVerification = [bool]$AllowLocalVerification
    } | ConvertTo-Json -Depth 5
} catch {
    [pscustomobject]@{
        status = 'FAIL'
        checkedAt = $startedAt.ToString('o')
        durationMs = [math]::Round(((Get-Date).ToUniversalTime() - $startedAt).TotalMilliseconds)
        failedCheck = $failedCheck
        error = $_.Exception.Message
        checks = $checks
        localVerification = [bool]$AllowLocalVerification
    } | ConvertTo-Json -Depth 5
    exit 1
} finally {
    if ($null -ne $httpClient) { $httpClient.Dispose() }
}
