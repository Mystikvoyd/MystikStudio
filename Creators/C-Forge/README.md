# C-Forge — Future C# Migration Scaffold

**Status:** Scaffold only — not an active Dashboard target.

## Purpose
Future C# counterpart for the current PowerShell Forge app.

## PowerShell Source App
- **Name:** Forge
- **Location:** `H:\MystikStudio\Creators\Forge`
- **Launch:** `Open Forge.vbs` → `Start-Forge.ps1`
- **Config:** `Forge.config.json`
- **Current Dashboard target:** `Creators\Forge\Open Forge.vbs`

## Planned Implementation
- **Exe name:** `Forge.exe`
- **Output path:** `Creators\C-Forge\build\Forge.exe`
- **Icon:** `H:\MystikStudio\Icons\Forge.ico`
- **Compile:** `csc.exe /target:winexe /win32icon:"H:\MystikStudio\Icons\Forge.ico"`
- **Dashboard target (future):** `Creators\C-Forge\build\Forge.exe`

## Known Inputs
- Character composition data
- Config: `Forge.config.json`
- ComfyUI workflow files

## Known Outputs
- Production-ready character images
- Reports

## Rollback
- Original PowerShell files remain at `Creators\Forge\`
- Archive rollback docs at `Creators\archive\Forge-PowerShell\README.txt`
- Do not use as active Dashboard target until migration is complete.
