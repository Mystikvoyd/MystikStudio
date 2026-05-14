# Activate-CSharpCreatorTargets.ps1
# After WDAC trust policy is installed and rebooted, this script tests whether
# C-Lab and C-Forge are trusted, and only then switches Dashboard targets.

$dashPath = "H:\MystikStudio\Start-MystikStudioDashboard.ps1"
$baseDir = "H:\MystikStudio\Creators"

$labExe = Join-Path $baseDir "C-Lab\Lab.exe"
$forgeExe = Join-Path $baseDir "C-Forge\Forge.exe"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Activate C# Creator Targets" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

$labOk = $false; $forgeOk = $false

# Test Lab
if (Test-Path $labExe) {
    $proc = Start-Process -FilePath $labExe -PassThru -WindowStyle Normal -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
    if ($proc -and !$proc.HasExited) { Write-Host "Lab.exe: TRUSTED (PID $($proc.Id))" -ForegroundColor Green; $proc.Kill(); $labOk = $true }
    else { Write-Host "Lab.exe: BLOCKED - will not activate" -ForegroundColor Red }
} else { Write-Host "Lab.exe: NOT FOUND" -ForegroundColor Yellow }

# Test Forge
if (Test-Path $forgeExe) {
    $proc = Start-Process -FilePath $forgeExe -PassThru -WindowStyle Normal -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
    if ($proc -and !$proc.HasExited) { Write-Host "Forge.exe: TRUSTED (PID $($proc.Id))" -ForegroundColor Green; $proc.Kill(); $forgeOk = $true }
    else { Write-Host "Forge.exe: BLOCKED - will not activate" -ForegroundColor Red }
} else { Write-Host "Forge.exe: NOT FOUND" -ForegroundColor Yellow }

Write-Host ""

if (-not $labOk -and -not $forgeOk) { Write-Host "Neither Lab nor Forge is trusted. Dashboard targets unchanged." -ForegroundColor Yellow; exit 1 }

if ($labOk -or $forgeOk) {
    Write-Host "Reading Dashboard: $dashPath" -ForegroundColor Yellow
    $content = Get-Content $dashPath -Raw
    $changed = $false

    if ($labOk) {
        if ($content -match 'Text="Lab".*Target=.*Open Lab.vbs') {
            $content = $content -replace '(@\{Text="Lab";[^}]*)Target=[^}]*(Creators\\)Lab\\Open Lab\.vbs([^}]*\})', ('$1Target=(Join-Path $StudioRoot "Creators\C-Lab\Lab.exe")$3')
            Write-Host "Lab target switched to: Creators\C-Lab\Lab.exe" -ForegroundColor Green
            $changed = $true
        } else { Write-Host "Lab target already set to C# or unknown - leaving unchanged." -ForegroundColor Yellow }
    }

    if ($forgeOk) {
        if ($content -match 'Text="Forge".*Target=.*Open Forge.vbs') {
            $content = $content -replace '(@\{Text="Forge";[^}]*)Target=[^}]*(Creators\\)Forge\\Open Forge\.vbs([^}]*\})', ('$1Target=(Join-Path $StudioRoot "Creators\C-Forge\Forge.exe")$3')
            Write-Host "Forge target switched to: Creators\C-Forge\Forge.exe" -ForegroundColor Green
            $changed = $true
        } else { Write-Host "Forge target already set to C# or unknown - leaving unchanged." -ForegroundColor Yellow }
    }

    if ($changed) {
        $content | Set-Content -Path $dashPath -Encoding UTF8
        $errors = $null; $null = [System.Management.Automation.Language.Parser]::ParseFile($dashPath, [ref]$null, [ref]$errors)
        if ($errors -and $errors.Count -gt 0) { Write-Host "ERROR: Parsing failed after edit! Reverting..." -ForegroundColor Red; git checkout -- $dashPath 2>$null; exit 1 }
        Write-Host "Dashboard updated and parsed successfully." -ForegroundColor Green
    } else { Write-Host "No target changes needed." -ForegroundColor Yellow }
}

Write-Host ""
Write-Host "Final Dashboard targets:" -ForegroundColor Cyan
Select-String -Path $dashPath -Pattern 'Text="Lab"|Text="Forge"' | Where-Object { $_ -match 'Target=' } | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
Write-Host ""
Write-Host "Done." -ForegroundColor Cyan
