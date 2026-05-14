# Restore-FusionLastKnownWorking.ps1
# Restores the exact grandfathered Fusion direct-launch binary from the LKG backup.
# Warning: This restores the OLD binary. Any source changes since the backup will be present in
# the source files but the exe will revert to its pre-build state.

$backupDir = "H:\MystikStudio\BACKUPS\LastKnownWorking\FusionDirectLaunch_20260513_204322"
$exeBackup = Join-Path $backupDir "C-Fusion.exe"
$exeLive = "H:\MystikStudio\Creators\C-Fusion\C-Fusion.exe"
$hashFile = Join-Path $backupDir "fusion-sha256.txt"
$expectedHash = (Get-Content $hashFile).Trim()

Write-Host "=============================================" -ForegroundColor Red
Write-Host "  RESTORE FUSION LAST KNOWN WORKING" -ForegroundColor Red
Write-Host "=============================================" -ForegroundColor Red
Write-Host ""
Write-Host "Backup: $backupDir" -ForegroundColor Yellow
Write-Host "Expected SHA256: $expectedHash" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Type RESTORE FUSION LKG to confirm"
if ($confirm -ne "RESTORE FUSION LKG") { Write-Host "Cancelled." -ForegroundColor Cyan; exit 0 }

if (-not (Test-Path $exeBackup)) { Write-Host "ERROR: Backup exe not found at $exeBackup" -ForegroundColor Red; exit 1 }

Copy-Item $exeBackup $exeLive -Force
Write-Host "C-Fusion.exe restored." -ForegroundColor Green

$actualHash = (Get-FileHash $exeLive -Algorithm SHA256).Hash
if ($actualHash -eq $expectedHash) {
    Write-Host "SHA256 verified: $actualHash" -ForegroundColor Green
} else {
    Write-Host "ERROR: SHA256 mismatch! Expected $expectedHash, got $actualHash" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "WARNING: This restores the grandfathered Fusion binary only." -ForegroundColor Yellow
Write-Host "If Fusion was rebuilt with new features, those changes are NOT in this backup." -ForegroundColor Yellow
Write-Host "Do not delete MystikStudioCreators.p7b from C:\Windows\System32\CodeIntegrity\" -ForegroundColor Yellow
Write-Host "Dashboard target must remain: Creators\C-Fusion\C-Fusion.exe" -ForegroundColor Yellow
Write-Host ""
Write-Host "Restore complete." -ForegroundColor Green
