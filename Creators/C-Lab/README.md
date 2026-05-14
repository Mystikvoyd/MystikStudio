# C-Lab — Staged C# Migration (WDAC Blocked)

**Status:** C# migration staged but BLOCKED by Microsoft WDAC Enterprise signing level.
**Dashboard target is permanently on PowerShell fallback** — the WDAC supplemental policy was attempted and removed.
**C# activation is NOT supported on this system** unless a future Microsoft-trusted code signing certificate is used.

## Trust Status
- **Signature:** Signed with `CN=MystikStudio Local Dev Code Signing` — Status: Valid
- **Thumbprint:** `03DF7DEC03A342769B3130D3C97888051E2CD22F`
- **Block source:** System base WDAC policy (Policy ID `{0283ac0f-fff1-49ae-ada1-8a933130cad6}`) at Enterprise signing level. Self-signed dev certificates do not meet this level. Supplemental WDAC policy was attempted (policy `{25AB9671-E031-4D8F-9E21-6880D5384D5B}`) and removed because the system did not accept it.
- **C# activation: NOT SUPPORTED** — The WDAC supplemental policy path does not work on this system. A Microsoft-trusted code signing certificate (EV or standard CA) would be needed to meet the Enterprise signing level. Until then, the PowerShell fallback is the only supported launch path.
- **Current hash:** `B1CE724529BCA0B1C98539B355A45B1696033BF173B47D992DF64AED3DFCEE7B`

## Active Dashboard Target
- **Current:** `Creators\Lab\Open Lab.vbs` (PowerShell — permanent fallback)
- **C# exe staged at:** `Creators\C-Lab\Lab.exe` (blocked — WDAC activation failed, do not retry)

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
