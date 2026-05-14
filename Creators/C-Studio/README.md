# C-Studio — Staged C# Migration

**Status:** Staged C# migration.
**Not yet active Dashboard target** until user confirms Studio.exe opens directly.
**Active Dashboard target remains Studio PowerShell** until confirmation.

## Trust Status
- **Signature:** Signed with `CN=MystikStudio Local Dev Code Signing`
- **Direct launch test:** Pending user confirmation

## Active Dashboard Target
- **Current:** `Creators\Studio\Open Studio.vbs` (PowerShell — working)
- **Staged:** `Creators\C-Studio\Studio.exe` (C# — signed, awaiting confirmation)

## PowerShell Source App
- **Name:** Studio
- **Location:** `H:\MystikStudio\Creators\Studio`
- **Launch:** `Open Studio.vbs` → `Start-Studio.ps1`
- **Config:** `Studio.config.json`

## Planned Implementation
- **Exe name:** `Studio.exe`
- **Output path:** `Creators\C-Studio\Studio.exe`
- **Icon:** `H:\MystikStudio\Icons\Studio.ico`

## Rollback
- Original PowerShell files remain at `Creators\Studio\`
- Archive rollback docs at `Creators\archive\Studio-PowerShell\README.txt`
