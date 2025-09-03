param(
    [Parameter(Mandatory = $true)] [string] $PngPath,
    [Parameter(Mandatory = $true)] [string] $OutIco
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$png = Resolve-Path $PngPath
$out = $OutIco
if (-not (Test-Path (Split-Path -Parent $out))) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $out) | Out-Null
}

# Read PNG bytes
$pngBytes = [System.IO.File]::ReadAllBytes($png)

# Create ICO with a single PNG-compressed 256x256 image
# ICO header (ICONDIR):
#   Reserved(2)=0, Type(2)=1, Count(2)=1
# ICONDIRENTRY (16 bytes):
#   Width(1)=0 for 256, Height(1)=0 for 256, ColorCount(1)=0, Reserved(1)=0,
#   Planes(2)=1, BitCount(2)=32, BytesInRes(4)=len, ImageOffset(4)=22

$fs = [System.IO.File]::Open($out, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
$bw = New-Object System.IO.BinaryWriter($fs)

# ICONDIR
$bw.Write([byte]0)
$bw.Write([byte]0)
$bw.Write([UInt16]1)
$bw.Write([UInt16]1)

# ICONDIRENTRY
$bw.Write([byte]0)      # width 256
$bw.Write([byte]0)      # height 256
$bw.Write([byte]0)      # color count
$bw.Write([byte]0)      # reserved
$bw.Write([UInt16]1)    # planes
$bw.Write([UInt16]32)   # bit count
$bw.Write([UInt32]$pngBytes.Length) # bytes in resource
$bw.Write([UInt32]22)   # image offset (6 + 16)

# Image data (PNG as-is)
$bw.Write($pngBytes)
$bw.Flush()
$bw.Close()
$fs.Close()

Write-Host "ICO written:" (Resolve-Path $out)

