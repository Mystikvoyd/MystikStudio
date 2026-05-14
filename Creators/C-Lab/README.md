# C-Lab — Future C# Migration Scaffold

**Status:** Staged C# migration — signed and launches directly.
**Not yet active Dashboard target** until user confirms switch.

## Trust Status
- **Signature:** Signed with `CN=MystikStudio Local Dev Code Signing` — Status: Valid
- **Thumbprint:** `03DF7DEC03A342769B3130D3C97888051E2CD22F`
- **Smart App Control:** Exe is signed but self-signed cert lacks cloud reputation.
  After the GPU status rebuild (Entry 55), the new binary hash requires a WDAC trust refresh.
- **WDAC policy:** Hash-based supplemental policy generated at `%TEMP%\MystikStudioCLab_v2.p7b`.
  **Admin must run the following in an elevated PowerShell, then reboot:**
  ```
  Copy-Item "$env:TEMP\MystikStudioCLab_v2.p7b" "C:\Windows\System32\CodeIntegrity\" -Force
  ```
- **Current hash:** `B1CE724529BCA0B1C98539B355A45B1696033BF173B47D992DF64AED3DFCEE7B`
- **Note:** Any future rebuild changes this hash, requiring a new WDAC policy. Consider switching to signer-based trust to avoid per-rebuild policy updates.

## Active Dashboard Target
- **Current:** `Creators\C-Lab\Lab.exe` (C# — active, trusted, opens directly)
- **Old PowerShell preserved as Lab-PS:** `Creators\Lab\`

## Purpose
Future C# counterpart for the current PowerShell Studio app.

## PowerShell Source App
- **Name:** Lab
- **Location:** `H:\MystikStudio\Creators\Lab`
- **Launch:** `Open Lab.vbs` → `Start-Lab.ps1`
- **Config:** `Lab.config.json`
- **Current Dashboard target:** `Creators\Lab\Open Lab.vbs` (PowerShell — working)
- **Staged Dashboard target:** `Creators\C-Lab\Lab.exe` (C# — blocked by Smart App Control)

## Planned Implementation
- **Exe name:** `Lab.exe`
- **Output path:** `Creators\C-Lab\Lab.exe`
- **Icon:** `H:\MystikStudio\Icons\Lab.ico`
- **Compile:** `csc.exe /target:winexe /win32icon:"H:\MystikStudio\Icons\Lab.ico"`

## Known Inputs
- LoRA model testing parameters
- Config: `Lab.config.json`
- ComfyUI workflow files

## Known Outputs
- LoRA test comparison images
- Run history: `Lab.runlog.json`
- Session reports

## Rollback
- Original PowerShell files remain at `Creators\Lab\`
- Archive rollback docs at `Creators\archive\Lab-PowerShell\README.txt`
- Do not activate as Dashboard target until signing/trust is solved.
