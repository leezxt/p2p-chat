$ErrorActionPreference = 'Stop'
$pruneScript = Join-Path $PSScriptRoot 'prune-production-backups.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "p2p-chat-retention-$([Guid]::NewGuid().ToString('N'))"
$backupDirectory = Join-Path $testRoot 'backups'
$receiptDirectory = Join-Path $testRoot 'receipts'
$referenceTime = [DateTimeOffset]'2026-07-15T00:00:00Z'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function New-BackupFixture {
    param(
        [string]$Name,
        [int]$AgeDays,
        [switch]$WithReceipt,
        [switch]$CorruptHash,
        [switch]$WithoutManifest
    )

    $dumpPath = Join-Path $backupDirectory "$Name.dump"
    [IO.File]::WriteAllBytes($dumpPath, [Text.Encoding]::UTF8.GetBytes("fixture-$Name"))
    if ($WithoutManifest) { return $dumpPath }
    $hash = (Get-FileHash -LiteralPath $dumpPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifestHash = if ($CorruptHash) { '0' * 64 } else { $hash }
    [ordered]@{
        schemaVersion = 1
        generatedAt = $referenceTime.AddDays(-$AgeDays).ToString('o')
        database = [ordered]@{ name = 'p2p_chat'; postgresToolVersion = 'fixture' }
        backup = [ordered]@{
            fileName = [IO.Path]::GetFileName($dumpPath)
            sizeBytes = (Get-Item -LiteralPath $dumpPath).Length
            sha256 = $manifestHash
            format = 'PostgreSQL custom'
        }
        verification = [ordered]@{ pgRestoreListPassed = $true }
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath "$dumpPath.manifest.json" -Encoding utf8NoBOM
    if ($WithReceipt) {
        [ordered]@{
            schemaVersion = 1
            backupSha256 = $hash
            verifiedAt = $referenceTime.AddDays(-1).ToString('o')
            storageReference = "fixture://off-host/$Name"
        } | ConvertTo-Json -Depth 5 | Set-Content `
            -LiteralPath (Join-Path $receiptDirectory "$Name.dump.offhost-receipt.json") `
            -Encoding utf8NoBOM
    }
    return $dumpPath
}

try {
    New-Item -ItemType Directory -Path $backupDirectory, $receiptDirectory | Out-Null
    $eligibleOldest = New-BackupFixture -Name 'eligible-oldest' -AgeDays 60 -WithReceipt
    $eligibleOlder = New-BackupFixture -Name 'eligible-older' -AgeDays 50 -WithReceipt
    $protectedNoReceipt = New-BackupFixture -Name 'protected-no-receipt' -AgeDays 40
    $recent = New-BackupFixture -Name 'recent' -AgeDays 5 -WithReceipt
    $corrupt = New-BackupFixture -Name 'corrupt' -AgeDays 80 -WithReceipt -CorruptHash
    $orphan = New-BackupFixture -Name 'orphan' -AgeDays 90 -WithoutManifest

    $plan = & $pruneScript `
        -BackupDirectory $backupDirectory `
        -OffHostReceiptDirectory $receiptDirectory `
        -MaxAgeDays 30 `
        -MinimumBackups 2 `
        -ReferenceTimeUtc $referenceTime | ConvertFrom-Json
    Assert-True ($plan.status -eq 'PLANNED') 'Dry-run did not return PLANNED.'
    Assert-True ($plan.candidates.Count -eq 2) 'Dry-run did not select exactly two eligible backups.'
    Assert-True ($plan.candidates -contains 'eligible-oldest.dump') 'Oldest eligible backup was not selected.'
    Assert-True ($plan.candidates -contains 'eligible-older.dump') 'Older eligible backup was not selected.'
    Assert-True (Test-Path -LiteralPath $eligibleOldest) 'Dry-run deleted a dump.'

    $wrongConfirmationRejected = $false
    try {
        & $pruneScript `
            -BackupDirectory $backupDirectory `
            -OffHostReceiptDirectory $receiptDirectory `
            -MaxAgeDays 30 `
            -MinimumBackups 2 `
            -ReferenceTimeUtc $referenceTime `
            -Apply `
            -Confirmation 'delete-verified-local-backups' | Out-Null
    } catch {
        $wrongConfirmationRejected = $_.Exception.Message -match 'Apply requires'
    }
    Assert-True $wrongConfirmationRejected 'Case-sensitive apply confirmation was not enforced.'

    $applied = & $pruneScript `
        -BackupDirectory $backupDirectory `
        -OffHostReceiptDirectory $receiptDirectory `
        -MaxAgeDays 30 `
        -MinimumBackups 2 `
        -ReferenceTimeUtc $referenceTime `
        -Apply `
        -Confirmation 'DELETE-VERIFIED-LOCAL-BACKUPS' | ConvertFrom-Json
    Assert-True ($applied.status -eq 'APPLIED') 'Apply did not return APPLIED.'
    Assert-True ($applied.deleted.Count -eq 2) 'Apply did not delete exactly two backups.'
    Assert-True (-not (Test-Path -LiteralPath $eligibleOldest)) 'Eligible oldest dump still exists.'
    Assert-True (-not (Test-Path -LiteralPath $eligibleOlder)) 'Eligible older dump still exists.'
    Assert-True (Test-Path -LiteralPath $protectedNoReceipt) 'Backup without receipt was deleted.'
    Assert-True (Test-Path -LiteralPath $recent) 'Recent backup was deleted.'
    Assert-True (Test-Path -LiteralPath $corrupt) 'Corrupt backup was deleted.'
    Assert-True (Test-Path -LiteralPath $orphan) 'Orphan backup was deleted.'

    $secondPlan = & $pruneScript `
        -BackupDirectory $backupDirectory `
        -OffHostReceiptDirectory $receiptDirectory `
        -MaxAgeDays 30 `
        -MinimumBackups 2 `
        -ReferenceTimeUtc $referenceTime | ConvertFrom-Json
    Assert-True ($secondPlan.candidates.Count -eq 0) 'Second dry-run was not idempotent.'

    [pscustomobject]@{
        status = 'PASS'
        dryRunCandidates = 2
        deleted = 2
        protectedRemaining = 4
        wrongConfirmationRejected = $true
        idempotent = $true
    } | ConvertTo-Json -Depth 5
} finally {
    $fullTestRoot = [IO.Path]::GetFullPath($testRoot)
    $fullTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($fullTestRoot.StartsWith($fullTemp, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($fullTestRoot) -match '^p2p-chat-retention-[0-9a-f]{32}$') {
        Remove-Item -LiteralPath $fullTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
