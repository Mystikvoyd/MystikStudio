# Build-CLab.ps1
# Compiles C# Lab using .NET Framework csc.exe
param(
    [ValidateSet("None", "Dev", "Release")]
    [string]$SignMode = "Dev",
    [string]$ReleaseCertPath = "",
    [string]$ReleaseCertPassword = "",
    [string]$TimestampUrl = "http://timestamp.digicert.com"
)

$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$baseDir = Split-Path -Parent $PSScriptRoot
$shared = Join-Path $baseDir "shared\GpuStatusProvider.cs"
$refs = @("System.dll", "System.Core.dll", "System.Drawing.dll", "System.Windows.Forms.dll", "System.Net.dll", "System.Web.Extensions.dll", "System.Data.dll", "System.Xml.dll", "System.Management.dll")
$refArgs = $refs | ForEach-Object { "/reference:$_" }

$versionFile = Join-Path $PSScriptRoot "version.txt"
$appVersion = "0.1.0-alpha.1"
if (Test-Path $versionFile) { $vc = Get-Content $versionFile -Raw; if ($vc -match 'Version:\s*(\S+)') { $appVersion = $matches[1] } }

Write-Host "Building C# Lab v$appVersion | SignMode: $SignMode" -ForegroundColor Cyan

$vcSrc = "using System; static class AppVersion { public static readonly string Value = `"$appVersion`"; }"
Set-Content -Path (Join-Path $PSScriptRoot "_version.cs") -Value $vcSrc -Encoding UTF8

$labOut = Join-Path $PSScriptRoot "Lab.exe"
if (Test-Path (Join-Path $PSScriptRoot "Lab.cs")) {
    & $csc /target:winexe /win32icon:"H:\MystikStudio\Icons\Lab.ico" /out:$labOut @refArgs (Join-Path $PSScriptRoot "_version.cs"), (Join-Path $PSScriptRoot "Lab.cs"), $shared 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Lab.exe built: $labOut" -ForegroundColor Green
    } else { Write-Host "Lab build failed" -ForegroundColor Red }
} else { Write-Host "Lab.cs not found" -ForegroundColor Yellow }

Remove-Item (Join-Path $PSScriptRoot "_version.cs") -Force -ErrorAction SilentlyContinue
