# Build-CForge.ps1
param([string]$SignMode = "Dev")
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$baseDir = Split-Path -Parent $PSScriptRoot
$shared = Join-Path $baseDir "shared\GpuStatusProvider.cs"
$refs = "/reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll /reference:System.Net.dll /reference:System.Web.Extensions.dll /reference:System.Data.dll /reference:System.Xml.dll /reference:System.Management.dll"
$forgeOut = Join-Path $PSScriptRoot "Forge.exe"
if (Test-Path (Join-Path $PSScriptRoot "Forge.cs")) {
    & $csc /target:winexe /win32icon:"H:\MystikStudio\Icons\Forge.ico" /out:$forgeOut @($refs.Split(" ")) (Join-Path $PSScriptRoot "_version.cs"), (Join-Path $PSScriptRoot "Forge.cs"), $shared 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Host "Forge.exe built: $forgeOut" -ForegroundColor Green } else { Write-Host "Forge build failed" -ForegroundColor Red }
} else { Write-Host "Forge.cs not found" -ForegroundColor Yellow }
Remove-Item (Join-Path $PSScriptRoot "_version.cs") -Force -ErrorAction SilentlyContinue
