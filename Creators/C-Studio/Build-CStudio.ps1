# Build-CStudio.ps1
param([string]$SignMode = "Dev")
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$refs = "/reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll /reference:System.Net.dll /reference:System.Web.Extensions.dll /reference:System.Data.dll /reference:System.Xml.dll"
$baseDir = Split-Path -Parent $PSScriptRoot
$versionFile = Join-Path $PSScriptRoot "version.txt"
$appVersion = "0.1.0-alpha.1"
if (Test-Path $versionFile) { $vc = Get-Content $versionFile -Raw; if ($vc -match 'Version:\s*(\S+)') { $appVersion = $matches[1] } }
Write-Host "Building C# Studio v$appVersion" -ForegroundColor Cyan
$vcSrc = "using System; static class AppVersion { public static readonly string Value = `"$appVersion`"; }"
Set-Content -Path (Join-Path $PSScriptRoot "_version.cs") -Value $vcSrc -Encoding UTF8
$studioOut = Join-Path $PSScriptRoot "Studio.exe"
if (Test-Path (Join-Path $PSScriptRoot "Studio.cs")) {
    & $csc /target:winexe /win32icon:"H:\MystikStudio\Icons\Studio.ico" /out:$studioOut @($refs.Split(" ")) (Join-Path $PSScriptRoot "_version.cs"), (Join-Path $PSScriptRoot "Studio.cs") 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Host "Studio.exe built: $studioOut" -ForegroundColor Green } else { Write-Host "Studio build failed" -ForegroundColor Red }
} else { Write-Host "Studio.cs not found" -ForegroundColor Yellow }
Remove-Item (Join-Path $PSScriptRoot "_version.cs") -Force -ErrorAction SilentlyContinue
