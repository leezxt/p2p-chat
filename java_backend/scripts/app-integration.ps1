$ErrorActionPreference = 'Stop'

$backend = Split-Path -Parent $PSScriptRoot
$repo = Split-Path -Parent $backend
$app = Join-Path $repo 'mobile_desktop_app'
$localDart = Join-Path $repo '.tools\flutter\bin\dart.bat'
$dart = if (Test-Path -LiteralPath $localDart) { $localDart } else { 'dart' }
$flutterRoot = (Join-Path $repo '.tools\flutter').Replace('\', '/')
$port = 18080
$baseUrl = "http://127.0.0.1:$port"

Push-Location $backend
try {
    mvn test-compile dependency:build-classpath `
        '-Dmdep.includeScope=test' `
        '-Dmdep.outputFile=target/test-classpath.txt'
    if ($LASTEXITCODE -ne 0) { throw 'Failed to build the backend test classpath.' }

    $dependencies = Get-Content 'target\test-classpath.txt' -Raw
    $classpath = (Join-Path $backend 'target\test-classes') + ';' +
        (Join-Path $backend 'target\classes') + ';' + $dependencies.Trim()
    $stdout = Join-Path $backend 'target\app-integration.out.log'
    $stderr = Join-Path $backend 'target\app-integration.err.log'
    $java = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin\java.exe' } else { $null }
    if (-not $java -or -not (Test-Path -LiteralPath $java)) {
        $java = (Get-Command java -ErrorAction Stop).Source
    }

    $process = Start-Process -FilePath $java `
        -ArgumentList @(
            '-Dspring.profiles.active=test',
            "-Dserver.port=$port",
            '-cp',
            $classpath,
            'com.p2pchat.P2pChatApplication'
        ) `
        -WorkingDirectory $backend `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr `
        -PassThru

    try {
        $health = $null
        $deadline = (Get-Date).AddSeconds(90)
        do {
            Start-Sleep -Seconds 2
            try {
                $health = Invoke-RestMethod "$baseUrl/actuator/health" -TimeoutSec 2
            } catch {
                $health = $null
            }
        } while (($null -eq $health -or $health.status -ne 'UP') -and (Get-Date) -lt $deadline)

        if ($null -eq $health -or $health.status -ne 'UP') {
            throw "Backend did not become healthy. See $stdout and $stderr."
        }

        $env:BACKEND_URL = $baseUrl
        $env:LOCAL_DEV_AUTH_KEY = 'test-local-dev-key'
        if ($dart -eq $localDart) {
            $env:GIT_CONFIG_COUNT = '1'
            $env:GIT_CONFIG_KEY_0 = 'safe.directory'
            $env:GIT_CONFIG_VALUE_0 = $flutterRoot
        }
        Push-Location $app
        try {
            & $dart run 'tool\backend_integration_check.dart'
            if ($LASTEXITCODE -ne 0) { throw 'App/backend integration check failed.' }
        } finally {
            Pop-Location
        }
    } finally {
        if ($process -and -not $process.HasExited) {
            taskkill.exe /PID $process.Id /T /F | Out-Null
        }
    }
} finally {
    Pop-Location
}
