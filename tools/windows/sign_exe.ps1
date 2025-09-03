param(
    [Parameter(Mandatory = $true)] [string] $ExePath,
    [string] $Subject = 'CN=flutter_application_1 Test Signing',
    [string] $PfxOut = $(Join-Path $env:TEMP 'flutter_application_1_test_signing.pfx'),
    [string] $PfxPassword = 'TempPfxPass123!',
    [string] $TimestampUrl = 'http://timestamp.digicert.com'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host 'Signing target:' (Resolve-Path $ExePath)

# Create a self-signed code signing certificate in CurrentUser\My
$cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject $Subject `
    -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 `
    -KeyExportPolicy Exportable -CertStoreLocation Cert:\CurrentUser\My `
    -NotAfter (Get-Date).AddYears(2)

# Export to PFX
$securePwd = ConvertTo-SecureString -String $PfxPassword -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath $PfxOut -Password $securePwd | Out-Null
Write-Host 'PFX:' $PfxOut
Write-Host 'Thumbprint:' $cert.Thumbprint

function Find-SignTool {
    $found = @()
    $cmd = Get-Command signtool.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue
    if ($cmd) { $found += $cmd }

    $roots = @('C:\\Program Files (x86)\\Windows Kits\\10\\bin', 'C:\\Program Files\\Windows Kits\\10\\bin')
    foreach ($root in $roots) {
        if (Test-Path $root) {
            $items = Get-ChildItem -Recurse -ErrorAction SilentlyContinue $root -Filter signtool.exe | Select-Object -ExpandProperty FullName -ErrorAction SilentlyContinue
            if ($items) { $found += $items }
        }
    }

    $found = $found | Where-Object { $_ -and (Test-Path $_) } | Sort-Object -Unique

    $pref64 = $found | Where-Object { $_ -match '\\x64\\' } | Select-Object -First 1
    if ($pref64) { return $pref64 }
    if ($found -and $found.Length -gt 0) { return $found[0] }
    return $null
}

$signTool = Find-SignTool
if ($signTool) {
    Write-Host 'Using signtool:' $signTool
    $signed = $false
    try {
        & $signTool sign /fd SHA256 /f $PfxOut /p $PfxPassword /tr $TimestampUrl /td SHA256 $ExePath
        $signed = $true
    } catch {
        Write-Warning 'Timestamp signing failed, retrying without timestamp.'
        & $signTool sign /fd SHA256 /f $PfxOut /p $PfxPassword $ExePath
        $signed = $true
    }
    if ($signed) {
        try {
            & $signTool verify /pa /v $ExePath | Out-Host
        } catch {
            Write-Warning 'signtool verify failed.'
        }
    }
} else {
    Write-Warning 'signtool not found. Falling back to Set-AuthenticodeSignature.'
    $pfxCert = Get-PfxCertificate -FilePath $PfxOut
    try {
        Set-AuthenticodeSignature -FilePath $ExePath -Certificate $pfxCert -TimestampServer $TimestampUrl -HashAlgorithm SHA256 | Format-List | Out-Host
    } catch {
        Write-Warning 'AuthenticodeSignature with timestamp failed, retrying without timestamp.'
        Set-AuthenticodeSignature -FilePath $ExePath -Certificate $pfxCert -HashAlgorithm SHA256 | Format-List | Out-Host
    }
}

Write-Host 'Signing completed.'

