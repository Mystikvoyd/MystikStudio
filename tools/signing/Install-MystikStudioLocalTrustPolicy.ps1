# Install-MystikStudioLocalTrustPolicy.ps1
# NOTE: WDAC supplemental policy installation was attempted and does not work on this system.
# The system base WDAC Enterprise signing level blocks self-signed dev certs.
# Supplemental policies cannot override this here. Keep PowerShell fallback for Lab and Forge.
# This script is preserved as a reference only.

param([switch]$Install, [switch]$Test, [switch]$Status)

$policyName = "MystikStudioCreators"
$policyStore = "C:\Windows\System32\CodeIntegrity"
$baseDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

$exes = @(
    @{Name = "Fusion"; Path = Join-Path $baseDir "Creators\C-Fusion\C-Fusion.exe"; Alt = Join-Path $baseDir "Creators\C-Fusion\Fusion.exe" },
    @{Name = "Lab";    Path = Join-Path $baseDir "Creators\C-Lab\Lab.exe" },
    @{Name = "Forge";  Path = Join-Path $baseDir "Creators\C-Forge\Forge.exe" }
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  MystikStudio Creator Trust Policy Installer" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

$validExes = @()
foreach ($ex in $exes) {
    $p = if (Test-Path $ex.Path) { $ex.Path } elseif (Test-Path $ex.Alt) { $ex.Alt } else { $null }
    if ($p) { $validExes += @{Name = $ex.Name; Path = $p; Hash = (Get-FileHash $p -Algorithm SHA256).Hash; Sig = Get-AuthenticodeSignature $p; Zone = Get-Item $p -Stream Zone.Identifier -ErrorAction SilentlyContinue }
        Write-Host "$($ex.Name): $p" -ForegroundColor Green
        Write-Host "  SHA256: $($validExes[-1].Hash)"
        Write-Host "  Signature: $($validExes[-1].Sig.Status)"
        if ($validExes[-1].Zone) { Write-Host "  MOTW: PRESENT - run: Unblock-File '$p'" -ForegroundColor Red } else { Write-Host "  MOTW: absent" }
    } else { Write-Host "$($ex.Name): EXE NOT FOUND at $($ex.Path)" -ForegroundColor Yellow }
}

if ($validExes.Count -eq 0) { Write-Host "ERROR: No creator exes found. Build C-Fusion, C-Lab, or C-Forge first." -ForegroundColor Red; exit 1 }

if ($Status) {
    $existing = Get-ChildItem "$policyStore\$policyName*.p7b" -ErrorAction SilentlyContinue
    if ($existing) { Write-Host "Policy installed: $($existing.Name)" -ForegroundColor Green } else { Write-Host "No $policyName policy installed." -ForegroundColor Yellow }
    exit 0
}

if (-not $Install) {
    Write-Host ""
    Write-Host "DRY RUN - No changes made." -ForegroundColor Cyan
    Write-Host "To install trust policy for $($validExes.Count) creator exe(s), run as Administrator:" -ForegroundColor Cyan
    Write-Host "  powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Install" -ForegroundColor White
    Write-Host ""
    Write-Host "WHAT THIS WILL DO:" -ForegroundColor Yellow
    Write-Host "  1. Generate a WDAC supplemental policy with hash rules for all listed exes"
    Write-Host "  2. Convert policy to binary (.p7b) and copy to $policyStore"
    Write-Host "  3. Reboot is REQUIRED for the policy to take effect"
    Write-Host "  4. After reboot, run: .\tools\Activate-CSharpCreatorTargets.ps1"
    exit 0
}

if (-not $isAdmin) { Write-Host "ERROR: -Install requires Administrator privileges." -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "INSTALLING..." -ForegroundColor Yellow

$scanDir = Join-Path $baseDir "Creators"
$scanXml = "$env:TEMP\${policyName}_scan.xml"
$finalXml = "$env:TEMP\${policyName}.xml"
$binPath = "$env:TEMP\${policyName}.p7b"

try {
    New-CIPolicy -FilePath $scanXml -ScanPath $scanDir -UserPEs -Level Hash -ErrorAction Stop | Out-Null
    Write-Host "  1. Policy XML generated: $scanXml" -ForegroundColor Green
} catch { Write-Host "  1. FAILED: New-CIPolicy could not generate policy: $_" -ForegroundColor Red; exit 1 }

$policy = [xml](Get-Content $scanXml)
$newGuid = [guid]::NewGuid().ToString().ToUpper()
$policy.SiPolicy.PolicyTypeID = "{$newGuid}"
$auditNodes = @()
for ($i = 0; $i -lt $policy.SiPolicy.Rules.ChildNodes.Count; $i++) { $r = $policy.SiPolicy.Rules.ChildNodes[$i]; if ($r.Option -and $r.Option -eq "Enabled:Audit Mode") { $auditNodes += $i } }
for ($i = $auditNodes.Count - 1; $i -ge 0; $i--) { [void]$policy.SiPolicy.Rules.RemoveChild($policy.SiPolicy.Rules.ChildNodes[$auditNodes[$i]]) }
$policy.Save($finalXml)
Write-Host "  2. Final policy XML: $finalXml" -ForegroundColor Green

try {
    ConvertFrom-CIPolicy -XmlFilePath $finalXml -BinaryFilePath $binPath -ErrorAction Stop | Out-Null
    Write-Host "  3. Binary policy: $binPath" -ForegroundColor Green
} catch { Write-Host "  3. FAILED to convert policy: $_" -ForegroundColor Red; exit 1 }

if (-not (Test-Path $policyStore)) { New-Item -ItemType Directory -Path $policyStore -Force | Out-Null }
Copy-Item $binPath "$policyStore\$policyName.p7b" -Force
Write-Host "  4. Policy copied: $policyStore\$policyName.p7b" -ForegroundColor Green

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  INSTALLATION COMPLETE" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "REBOOT IS REQUIRED for the policy to take effect." -ForegroundColor Yellow
Write-Host ""
Write-Host "After reboot, verify trust with:" -ForegroundColor Cyan
Write-Host "  .\tools\signing\Test-MystikStudioCreatorTrust.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Then activate C# targets with:" -ForegroundColor Cyan
Write-Host "  .\tools\Activate-CSharpCreatorTargets.ps1" -ForegroundColor White

