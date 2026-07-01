param(
    [string] $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')),
    [string] $Configuration = 'Release',
    [string] $Arch = 'x64',
    [string] $OutDir = (Join-Path $ProjectRoot 'dist'),
    [switch] $Build
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-PubspecVersion([string] $pubspecPath) {
    if (-not (Test-Path $pubspecPath)) { return $null }
    $line = (Get-Content -Path $pubspecPath -Encoding UTF8 | Where-Object { $_ -match '^\s*version:\s*' } | Select-Object -First 1)
    if (-not $line) { return $null }
    $v = ($line -replace '^\s*version:\s*', '').Trim()
    return $v
}

$projectRootResolved = Resolve-Path $ProjectRoot
Write-Host "ProjectRoot:" $projectRootResolved

if ($Build) {
    Push-Location $projectRootResolved
    try {
        Write-Host "Building: flutter build windows --$Configuration"
        & flutter build windows "--$($Configuration.ToLower())"
        if ($LASTEXITCODE -ne 0) { throw "flutter build failed with exit code $LASTEXITCODE" }
    } finally {
        Pop-Location
    }
}

$releaseDir = Join-Path $projectRootResolved "build\windows\$Arch\runner\$Configuration"
if (-not (Test-Path $releaseDir)) {
    throw "Build output not found: $releaseDir`nRun: flutter build windows --release"
}

$pubspec = Join-Path $projectRootResolved 'pubspec.yaml'
$version = Read-PubspecVersion $pubspec
if (-not $version) { $version = '0.0.0+0' }
$safeVersion = ($version -replace '[^0-9A-Za-z\.\+\-_]', '_')

# Try to infer exe name (first *.exe in output dir)
$exe = Get-ChildItem -Path $releaseDir -Filter *.exe -File | Select-Object -First 1
if (-not $exe) { throw "No .exe found in $releaseDir" }

$appName = [System.IO.Path]::GetFileNameWithoutExtension($exe.Name)
$zipName = "$appName-windows-$Arch-$safeVersion.zip"

if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
}

$zipPath = Join-Path $OutDir $zipName
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }

# Create a staging directory to avoid zipping absolute paths
$stageRoot = Join-Path $env:TEMP ("flutter_win_dist_" + [Guid]::NewGuid().ToString('N'))
$stageApp = Join-Path $stageRoot $appName
New-Item -ItemType Directory -Force -Path $stageApp | Out-Null

Write-Host "Staging from:" $releaseDir
Write-Host "Staging to  :" $stageApp

try {
    Copy-Item -Path (Join-Path $releaseDir '*') -Destination $stageApp -Recurse -Force
} catch {
    # Rarely, AV scanners or indexing can transiently lock files; retry once after a short delay.
    Start-Sleep -Milliseconds 300
    Copy-Item -Path (Join-Path $releaseDir '*') -Destination $stageApp -Recurse -Force
}

# Sanity checks: ensure the runtime bundle exists
$required = @(
    (Join-Path $stageApp ($appName + '.exe')),
    (Join-Path $stageApp 'flutter_windows.dll'),
    (Join-Path $stageApp 'data\icudtl.dat')
)
foreach ($p in $required) {
    if (-not (Test-Path $p)) {
        throw "Missing required file in staged bundle: $p"
    }
}

$assetManifestPaths = @(
    (Join-Path $stageApp 'data\flutter_assets\AssetManifest.bin'),
    (Join-Path $stageApp 'data\flutter_assets\AssetManifest.json')
)
if (-not ($assetManifestPaths | Where-Object { Test-Path $_ })) {
    throw "Missing required file in staged bundle: AssetManifest.bin or AssetManifest.json"
}

function Try-CompressArchive([string] $sourceGlob, [string] $destinationZip) {
    $attempts = 8
    for ($i = 1; $i -le $attempts; $i++) {
        try {
            Compress-Archive -Path $sourceGlob -DestinationPath $destinationZip -Force
            return $true
        } catch {
            if ($i -eq $attempts) { break }
            # Backoff: 200ms, 400ms, ... (up to ~1.6s)
            $delay = 200 * [Math]::Pow(2, ($i - 1))
            Write-Warning ("Compress-Archive failed (attempt {0}/{1}). Retrying in {2}ms. Error: {3}" -f $i, $attempts, [int]$delay, $_.Exception.Message)
            Start-Sleep -Milliseconds ([int]$delay)
        }
    }
    return $false
}

function Try-TarZip([string] $baseDir, [string] $folderName, [string] $destinationZip) {
    $tar = (Get-Command tar.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)
    if (-not $tar) { return $false }
    try {
        & $tar -a -c -f $destinationZip -C $baseDir $folderName
        if ($LASTEXITCODE -ne 0) { throw "tar.exe failed with exit code $LASTEXITCODE" }
        return $true
    } catch {
        Write-Warning ("tar.exe fallback failed. Error: {0}" -f $_.Exception.Message)
        return $false
    }
}

try {
    Write-Host "Creating zip:" $zipPath

    $ok = Try-CompressArchive (Join-Path $stageRoot '*') $zipPath
    if (-not $ok) {
        Write-Warning "Compress-Archive failed after retries. Falling back to tar.exe..."
        $ok = Try-TarZip $stageRoot $appName $zipPath
    }

    if (-not $ok) {
        throw "Failed to create zip: $zipPath"
    }
} finally {
    if (Test-Path $stageRoot) {
        try { Remove-Item -Recurse -Force $stageRoot } catch { }
    }
}

Write-Host "Done."
Write-Host "Output:" (Resolve-Path $zipPath)


