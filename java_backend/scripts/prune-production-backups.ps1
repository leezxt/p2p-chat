[CmdletBinding()]
param(
    [string]$BackupDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'target\production-backups'),

    [string]$OffHostReceiptDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'target\production-backup-receipts'),

    [ValidateRange(1, 3650)]
    [int]$MaxAgeDays = 30,

    [ValidateRange(1, 1000)]
    [int]$MinimumBackups = 7,

    [DateTimeOffset]$ReferenceTimeUtc = [DateTimeOffset]::UtcNow,

    [switch]$Apply,

    [string]$Confirmation
)

$ErrorActionPreference = 'Stop'

function Get-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [IO.Path]::GetFullPath($Path)
}

function Assert-DirectChildPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Parent
    )

    $fullPath = Get-FullPath -Path $Path
    $fullParent = (Get-FullPath -Path $Parent).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    if ([IO.Path]::GetDirectoryName($fullPath) -cne $fullParent) {
        throw "Refusing path outside the expected directory: $fullPath"
    }
    return $fullPath
}

function Test-ReparsePoint {
    param([Parameter(Mandatory = $true)][IO.FileSystemInfo]$Item)
    return ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
}

if ($Apply -and $Confirmation -cne 'DELETE-VERIFIED-LOCAL-BACKUPS') {
    throw "Apply requires -Confirmation 'DELETE-VERIFIED-LOCAL-BACKUPS'."
}

$resolvedBackupDirectory = (Resolve-Path -LiteralPath $BackupDirectory -ErrorAction Stop).Path
$resolvedReceiptDirectory = Get-FullPath -Path $OffHostReceiptDirectory
$cutoff = $ReferenceTimeUtc.ToUniversalTime().AddDays(-$MaxAgeDays)
$validBackups = [Collections.Generic.List[object]]::new()
$protected = [Collections.Generic.List[object]]::new()

foreach ($dump in Get-ChildItem -LiteralPath $resolvedBackupDirectory -Filter '*.dump' -File) {
    $manifestPath = Assert-DirectChildPath -Path "$($dump.FullName).manifest.json" -Parent $resolvedBackupDirectory
    $receiptPath = Assert-DirectChildPath -Path (Join-Path $resolvedReceiptDirectory "$($dump.Name).offhost-receipt.json") -Parent $resolvedReceiptDirectory
    $reason = $null
    $manifest = $null
    $generatedAt = [DateTimeOffset]::MinValue
    $actualHash = $null

    try {
        if (Test-ReparsePoint -Item $dump) { throw 'dump is a reparse point' }
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'manifest is missing' }
        $manifestFile = Get-Item -LiteralPath $manifestPath
        if (Test-ReparsePoint -Item $manifestFile) { throw 'manifest is a reparse point' }
        $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json -Depth 20
        if ([int]$manifest.schemaVersion -ne 1) { throw 'manifest schemaVersion is not 1' }
        if ([string]$manifest.backup.fileName -cne $dump.Name) { throw 'manifest fileName does not match dump' }
        if ([long]$manifest.backup.sizeBytes -ne $dump.Length) { throw 'manifest size does not match dump' }
        if ([string]$manifest.backup.format -cne 'PostgreSQL custom' -or -not [bool]$manifest.verification.pgRestoreListPassed) {
            throw 'manifest does not describe a verified PostgreSQL custom dump'
        }
        if (-not [DateTimeOffset]::TryParse([string]$manifest.generatedAt, [ref]$generatedAt)) {
            throw 'manifest generatedAt is invalid'
        }
        $generatedAt = $generatedAt.ToUniversalTime()
        if ($generatedAt -gt $ReferenceTimeUtc.ToUniversalTime().AddMinutes(5)) { throw 'manifest generatedAt is in the future' }
        $actualHash = (Get-FileHash -LiteralPath $dump.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        if ([string]$manifest.backup.sha256 -cne $actualHash) { throw 'manifest SHA-256 does not match dump' }
    } catch {
        $reason = $_.Exception.Message
    }

    if ($null -ne $reason) {
        $protected.Add([pscustomobject]@{ fileName = $dump.Name; reason = $reason })
        continue
    }

    $receiptVerified = $false
    $receiptReason = $null
    try {
        if (-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)) { throw 'off-host receipt is missing' }
        $receiptFile = Get-Item -LiteralPath $receiptPath
        if (Test-ReparsePoint -Item $receiptFile) { throw 'off-host receipt is a reparse point' }
        $receipt = Get-Content -Raw -LiteralPath $receiptPath | ConvertFrom-Json -Depth 10
        $receiptSchemaVersion = [int]$receipt.schemaVersion
        if ($receiptSchemaVersion -notin @(1, 2)) { throw 'off-host receipt schemaVersion is unsupported' }
        if ([string]$receipt.backupSha256 -cne $actualHash) { throw 'off-host receipt SHA-256 does not match dump' }
        if ($receiptSchemaVersion -eq 2) {
            $manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
            if ([string]$receipt.manifestSha256 -cne $manifestHash) {
                throw 'off-host receipt manifest SHA-256 does not match'
            }
            if ([long]$receipt.sizeBytes -ne $dump.Length) { throw 'off-host receipt size does not match dump' }
        }
        if ([string]::IsNullOrWhiteSpace([string]$receipt.storageReference)) { throw 'off-host receipt storageReference is empty' }
        $verifiedAt = [DateTimeOffset]::MinValue
        if (-not [DateTimeOffset]::TryParse([string]$receipt.verifiedAt, [ref]$verifiedAt)) {
            throw 'off-host receipt verifiedAt is invalid'
        }
        if ($verifiedAt.ToUniversalTime() -gt $ReferenceTimeUtc.ToUniversalTime().AddMinutes(5)) {
            throw 'off-host receipt verifiedAt is in the future'
        }
        $receiptVerified = $true
    } catch {
        $receiptReason = $_.Exception.Message
    }

    if (-not $receiptVerified) {
        $protected.Add([pscustomobject]@{ fileName = $dump.Name; reason = $receiptReason })
    }
    $validBackups.Add([pscustomobject]@{
        fileName = $dump.Name
        dumpPath = $dump.FullName
        manifestPath = $manifestPath
        receiptPath = $receiptPath
        sha256 = $actualHash
        generatedAt = $generatedAt
        receiptVerified = $receiptVerified
    })
}

$orderedBackups = @($validBackups | Sort-Object generatedAt -Descending)
$retainedPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($backup in $orderedBackups | Select-Object -First $MinimumBackups) {
    [void]$retainedPaths.Add([string]$backup.dumpPath)
}
$candidates = @($orderedBackups | Where-Object {
    $_.receiptVerified -and $_.generatedAt -lt $cutoff -and -not $retainedPaths.Contains([string]$_.dumpPath)
})

$deleted = [Collections.Generic.List[string]]::new()
if ($Apply) {
    foreach ($candidate in $candidates) {
        $dumpPath = Assert-DirectChildPath -Path $candidate.dumpPath -Parent $resolvedBackupDirectory
        $manifestPath = Assert-DirectChildPath -Path $candidate.manifestPath -Parent $resolvedBackupDirectory
        $receiptPath = Assert-DirectChildPath -Path $candidate.receiptPath -Parent $resolvedReceiptDirectory
        foreach ($path in @($dumpPath, $manifestPath, $receiptPath)) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                throw "Backup record changed after planning; refusing deletion: $($candidate.fileName)"
            }
            if (Test-ReparsePoint -Item (Get-Item -LiteralPath $path)) {
                throw "Backup record became a reparse point; refusing deletion: $($candidate.fileName)"
            }
        }
        $currentHash = (Get-FileHash -LiteralPath $dumpPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($currentHash -cne $candidate.sha256) {
            throw "Backup changed after planning; refusing deletion: $($candidate.fileName)"
        }
        $currentManifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json -Depth 20
        $currentReceipt = Get-Content -Raw -LiteralPath $receiptPath | ConvertFrom-Json -Depth 10
        if ([int]$currentManifest.schemaVersion -ne 1 -or
            [string]$currentManifest.backup.fileName -cne [IO.Path]::GetFileName($dumpPath) -or
            [long]$currentManifest.backup.sizeBytes -ne (Get-Item -LiteralPath $dumpPath).Length -or
            [string]$currentManifest.backup.format -cne 'PostgreSQL custom' -or
            -not [bool]$currentManifest.verification.pgRestoreListPassed -or
            [string]$currentManifest.backup.sha256 -cne $currentHash) {
            throw "Backup manifest changed after planning; refusing deletion: $($candidate.fileName)"
        }
        $currentReceiptSchemaVersion = [int]$currentReceipt.schemaVersion
        if ($currentReceiptSchemaVersion -notin @(1, 2) -or
            [string]::IsNullOrWhiteSpace([string]$currentReceipt.storageReference)) {
            throw "Backup receipt changed after planning; refusing deletion: $($candidate.fileName)"
        }
        $currentVerifiedAt = [DateTimeOffset]::MinValue
        if (-not [DateTimeOffset]::TryParse([string]$currentReceipt.verifiedAt, [ref]$currentVerifiedAt) -or
            $currentVerifiedAt.ToUniversalTime() -gt $ReferenceTimeUtc.ToUniversalTime().AddMinutes(5)) {
            throw "Backup receipt changed after planning; refusing deletion: $($candidate.fileName)"
        }
        $receiptMetadataMatches = [string]$currentReceipt.backupSha256 -ceq $currentHash
        if ($currentReceiptSchemaVersion -eq 2) {
            $currentManifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
            $receiptMetadataMatches = $receiptMetadataMatches -and
                [string]$currentReceipt.manifestSha256 -ceq $currentManifestHash -and
                [long]$currentReceipt.sizeBytes -eq (Get-Item -LiteralPath $dumpPath).Length
        }
        if (-not $receiptMetadataMatches) {
            throw "Backup metadata changed after planning; refusing deletion: $($candidate.fileName)"
        }
        Remove-Item -LiteralPath $dumpPath -Force
        Remove-Item -LiteralPath $manifestPath -Force
        Remove-Item -LiteralPath $receiptPath -Force
        $deleted.Add([string]$candidate.fileName)
    }
}

[pscustomobject]@{
    status = if ($Apply) { 'APPLIED' } else { 'PLANNED' }
    referenceTimeUtc = $ReferenceTimeUtc.ToUniversalTime().ToString('o')
    cutoffUtc = $cutoff.ToString('o')
    maxAgeDays = $MaxAgeDays
    minimumBackups = $MinimumBackups
    validBackupCount = $validBackups.Count
    protected = @($protected)
    candidates = @($candidates | ForEach-Object { $_.fileName })
    deleted = @($deleted)
} | ConvertTo-Json -Depth 8
