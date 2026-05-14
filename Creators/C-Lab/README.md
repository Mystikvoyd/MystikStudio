# C-Lab — Staged C# Migration

**Status:** Staged C# migration. Blocked by system WDAC Enterprise signing level.
**Dashboard target restored to PowerShell fallback** until admin installs supplemental WDAC policy.

## Trust Status
- **Signature:** Signed with `CN=MystikStudio Local Dev Code Signing` — Status: Valid
- **Thumbprint:** `03DF7DEC03A342769B3130D3C97888051E2CD22F`
- **Block source:** System base WDAC policy (Policy ID `{0283ac0f-fff1-49ae-ada1-8a933130cad6}`) at Enterprise signing level. Self-signed certs do not meet this level.
- **WDAC supplemental policy:** Pre-generated at `%TEMP%\MystikStudioCLab_v2.p7b` — requires admin to install:
  ```
  Copy-Item "$env:TEMP\MystikStudioCLab_v2.p7b" "C:\Windows\System32\CodeIntegrity\" -Force
  Restart-Computer
  ```
- **Current hash:** `B1CE724529BCA0B1C98539B355A45B1696033BF173B47D992DF64AED3DFCEE7B`
- **Note:** Dashboard restored to PowerShell fallback (Creators\Lab\Open Lab.vbs). Switch back to C# exe after WDAC policy is installed and confirmed working.

## Active Dashboard Target
- **Current:** `Creators\Lab\Open Lab.vbs` (PowerShell — fallback)
- **C# exe staged at:** `Creators\C-Lab\Lab.exe` (blocked until WDAC policy installed)

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
