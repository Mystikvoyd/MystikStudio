# C-Forge — Staged C# Migration

**Status:** Staged C# migration.
**Not yet active Dashboard target** until user confirms Forge.exe opens directly.
**Active Dashboard target remains Forge PowerShell** until confirmation.

## Trust Status
- **Signature:** Signed with `CN=MystikStudio Local Dev Code Signing`
- **Direct launch test:** Pending user confirmation
- **WDAC policy:** Not installed separately. If needed, follow Fusion/Lab hash-based WDAC pattern.

## Active Dashboard Target
- **Current:** `Creators\Forge\Open Forge.vbs` (PowerShell — working)
- **Staged:** `Creators\C-Forge\Forge.exe` (C# — signed, awaiting confirmation)

## PowerShell Source App
- **Name:** Forge
- **Location:** `H:\MystikStudio\Creators\Forge`
- **Launch:** `Open Forge.vbs` → `Start-Forge.ps1`
- **Config:** `Forge.config.json`

## Planned Implementation
- **Exe name:** `Forge.exe`
- **Output path:** `Creators\C-Forge\Forge.exe`
- **Icon:** `H:\MystikStudio\Icons\Forge.ico`

## Rollback
- Original PowerShell files remain at `Creators\Forge\`
- Archive rollback docs at `Creators\archive\Forge-PowerShell\README.txt`
