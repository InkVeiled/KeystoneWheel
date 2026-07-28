[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$addonName = "KeystoneWheel"
$repoRoot = Split-Path -Parent $PSScriptRoot
$tocPath = Join-Path $repoRoot "$addonName.toc"
$sourceFiles = @(
    "$addonName.toc",
    "Locale.lua",
    "Core.lua",
    "UI.lua",
    "Media/WheelBackdrop.tga",
    "README.md",
    "RELEASE_CHECKLIST.md",
    "LICENSE"
)

if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
    throw "Missing TOC file: $tocPath"
}

$versionLine = Select-String -LiteralPath $tocPath -Pattern '^## Version:\s*(.+?)\s*$' |
    Select-Object -First 1

if (-not $versionLine) {
    throw "No Version field found in $addonName.toc."
}

$version = $versionLine.Matches[0].Groups[1].Value
if ($version -notmatch '^\d+\.\d+\.\d+$') {
    throw "TOC version '$version' must use the form 1.2.3."
}

$missingFiles = @(
    foreach ($relativePath in $sourceFiles) {
        $sourcePath = Join-Path $repoRoot $relativePath
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            $relativePath
        }
    }
)

if ($missingFiles.Count -gt 0) {
    throw "Missing release files: $($missingFiles -join ', ')"
}

$distPath = Join-Path $repoRoot "dist"
$archivePath = Join-Path $distPath "$addonName-local-v$version.zip"

New-Item -ItemType Directory -Path $distPath -Force | Out-Null
if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open(
    $archivePath,
    [System.IO.Compression.ZipArchiveMode]::Create
)
try {
    foreach ($relativePath in $sourceFiles) {
        $sourcePath = Join-Path $repoRoot $relativePath
        $entryName = "$addonName/$($relativePath.Replace('\', '/'))"
        $entry = $archive.CreateEntry(
            $entryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        )
        $entryStream = $entry.Open()
        $sourceStream = [System.IO.File]::OpenRead($sourcePath)
        try {
            $sourceStream.CopyTo($entryStream)
        }
        finally {
            $sourceStream.Dispose()
            $entryStream.Dispose()
        }
    }
}
finally {
    $archive.Dispose()
}

$archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    $entryNames = @($archive.Entries | ForEach-Object {
        $_.FullName.Replace('\', '/')
    })
    $expectedToc = "$addonName/$addonName.toc"

    if ($entryNames -notcontains $expectedToc) {
        throw "Archive does not contain $expectedToc."
    }

    $outsideAddon = @($entryNames | Where-Object {
        $_ -and -not $_.StartsWith("$addonName/")
    })
    if ($outsideAddon.Count -gt 0) {
        throw "Archive contains files outside $addonName/."
    }
}
finally {
    $archive.Dispose()
}

Write-Host "Local release candidate verified:"
Write-Host "  $archivePath"
Write-Host "Version, required files, top-level folder and TOC structure are valid."
Write-Host "Nothing was committed, tagged, pushed or published."
