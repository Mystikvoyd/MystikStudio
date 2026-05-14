# Test-MystikStudioCreatorTrust.ps1
# Tests trust status for all C# creator exes: Fusion, Lab, Forge.

$baseDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$exes = @{Fusion = @("Creators\C-Fusion\C-Fusion.exe", "Creators\C-Fusion\Fusion.exe"); Lab = @("Creators\C-Lab\Lab.exe"); Forge = @("Creators\C-Forge\Forge.exe") }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  MystikStudio Creator Trust Test" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

$allOk = $true
foreach ($name in $exes.Keys) {
    Write-Host "--- $name ---" -ForegroundColor Yellow
    $paths = $exes[$name]; $exePath = $null
    foreach ($p in $paths) { $fp = Join-Path $baseDir $p; if (Test-Path $fp) { $exePath = $fp; break } }
    if (-not $exePath) { Write-Host "  Exe not found." -ForegroundColor Red; $allOk = $false; continue }
    Write-Host "  Path:   $exePath"
    $sig = Get-AuthenticodeSignature $exePath
    Write-Host "  Signature: $($sig.Status)"
    if ($sig.Status -eq "Valid") { Write-Host "  Signer: $($sig.SignerCertificate.Subject)" }
    $hash = (Get-FileHash $exePath -Algorithm SHA256).Hash
    Write-Host "  SHA256: $hash"
    $zone = Get-Item $exePath -Stream Zone.Identifier -ErrorAction SilentlyContinue
    if ($zone) { Write-Host "  MOTW: PRESENT - run Unblock-File" -ForegroundColor Red; $allOk = $false } else { Write-Host "  MOTW: absent" }
    $proc = Start-Process -FilePath $exePath -PassThru -WindowStyle Normal -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    if ($proc -and !$proc.HasExited) { Write-Host "  Launch: OK (PID $($proc.Id))" -ForegroundColor Green; $proc.Kill() }
    elseif ($proc -and $proc.HasExited) { Write-Host "  Launch: EXITED ($($proc.ExitCode))" -ForegroundColor Red; $allOk = $false }
    else { Write-Host "  Launch: BLOCKED by App Control" -ForegroundColor Red; $allOk = $false }
    Write-Host ""
}

Write-Host "=============================================" -ForegroundColor Cyan
if ($allOk) { Write-Host "  ALL CREATOR EXES ARE TRUSTED" -ForegroundColor Green; exit 0 }
else { Write-Host "  SOME EXES ARE STILL BLOCKED" -ForegroundColor Yellow; exit 1 }
