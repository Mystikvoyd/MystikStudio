# Build-CForge.ps1
# Compiles C# Forge using .NET Framework csc.exe
param(
    [ValidateSet("None", "Dev", "Release")]
    [string]$SignMode = "Dev"
)

$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$baseDir = Split-Path -Parent $PSScriptRoot
$shared = Join-Path $baseDir "shared\GpuStatusProvider.cs"
$refs = @("System.dll", "System.Core.dll", "System.Drawing.dll", "System.Windows.Forms.dll", "System.Net.dll", "System.Web.Extensions.dll", "System.Data.dll", "System.Xml.dll", "System.Management.dll")
$refArgs = $refs | ForEach-Object { "/reference:$_" }

$versionFile = Join-Path $PSScriptRoot "version.txt"
$appVersion = "0.1.0-alpha.1"
if (Test-Path $versionFile) { $vc = Get-Content $versionFile -Raw; if ($vc -match 'Version:\s*(\S+)') { $appVersion = $matches[1] } }

Write-Host "Building C# Forge v$appVersion | SignMode: $SignMode" -ForegroundColor Cyan

$vcSrc = "using System; static class AppVersion { public static readonly string Value = `"$appVersion`"; }"
Set-Content -Path (Join-Path $PSScriptRoot "_version.cs") -Value $vcSrc -Encoding UTF8

function New-PatchedForgeSource {
    param([string]$SourcePath, [string]$OutPath)
    $sourceText = Get-Content -Path $SourcePath -Raw
    $sourceText = $sourceText.Replace('Height = 48, BackColor', 'Height = 54, BackColor')
    $sourceText = $sourceText -replace 'BorderStyle = BorderStyle\.None \}', 'BorderStyle = BorderStyle.None, AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill }'
    $sourceText = $sourceText.Replace('gridOutputs.Columns.Add("Time", "Time"); gridOutputs.Columns.Add("File", "File"); gridOutputs.Columns.Add("LoRA1", "LoRA1"); gridOutputs.Columns.Add("LoRA2", "LoRA2"); gridOutputs.Columns.Add("Seed", "Seed"); gridOutputs.Columns.Add("Path", "Path");', 'gridOutputs.Columns.Add("Time", "Time"); gridOutputs.Columns.Add("File", "File"); gridOutputs.Columns.Add("LoRA1", "LoRA1"); gridOutputs.Columns.Add("LoRA2", "LoRA2"); gridOutputs.Columns.Add("LoRA3", "LoRA3"); gridOutputs.Columns.Add("Seed", "Seed"); gridOutputs.Columns.Add("Path", "Path");')
    $sourceText = $sourceText.Replace('gridOutputs.Columns[5].Visible = false;', 'gridOutputs.Columns[6].Visible = false; gridOutputs.Columns[0].FillWeight = 10; gridOutputs.Columns[1].FillWeight = 38; gridOutputs.Columns[2].FillWeight = 14; gridOutputs.Columns[3].FillWeight = 14; gridOutputs.Columns[4].FillWeight = 14; gridOutputs.Columns[5].FillWeight = 10;')
    $oldInsert = @'
gridOutputs.Rows.Insert(0, DateTime.Now.ToString("HH:mm:ss"), Path.GetFileName(finalPath), (comboLora1.SelectedItem != null ? comboLora1.SelectedItem.ToString() : ""), seed.ToString(), finalPath);
'@.Trim()
    $newInsert = @'
gridOutputs.Rows.Insert(0, DateTime.Now.ToString("HH:mm:ss"), Path.GetFileName(finalPath), (comboLora1.SelectedItem != null ? comboLora1.SelectedItem.ToString() : ""), (comboLora2.SelectedItem != null ? comboLora2.SelectedItem.ToString() : ""), (comboLora3.SelectedItem != null ? comboLora3.SelectedItem.ToString() : ""), seed.ToString(), finalPath);
'@.Trim()
    $sourceText = $sourceText.Replace($oldInsert, $newInsert)
    $sourceText = $sourceText.Replace('.ToString("0.0") + " / "', '.ToString("0.0") + " GB / "')
    $sourceText = $sourceText.Replace(': "? / "', ': "? GB / "')
    Set-Content -Path $OutPath -Value $sourceText -Encoding UTF8
}

$forgeSource = Join-Path $PSScriptRoot "Forge.cs"
$generatedSource = Join-Path $PSScriptRoot "_generated_Forge.cs"
$forgeOut = Join-Path $PSScriptRoot "Forge.exe"
if (Test-Path $forgeSource) {
    New-PatchedForgeSource -SourcePath $forgeSource -OutPath $generatedSource
    & $csc /target:winexe /win32icon:"H:\MystikStudio\Icons\Forge.ico" /out:$forgeOut @refArgs (Join-Path $PSScriptRoot "_version.cs"), $generatedSource, $shared 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Host "Forge.exe built: $forgeOut" -ForegroundColor Green } else { Write-Host "Forge build failed" -ForegroundColor Red }
} else { Write-Host "Forge.cs not found" -ForegroundColor Yellow }

Remove-Item (Join-Path $PSScriptRoot "_version.cs") -Force -ErrorAction SilentlyContinue
Remove-Item $generatedSource -Force -ErrorAction SilentlyContinue
