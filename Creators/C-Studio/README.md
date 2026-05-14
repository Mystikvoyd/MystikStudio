# C-Studio — Future C# Migration Scaffold

**Status:** Scaffold only — not an active Dashboard target.

## Purpose
Future C# counterpart for the current PowerShell Studio app.

## PowerShell Source App
- **Name:** Studio
- **Location:** `H:\MystikStudio\Creators\Studio`
- **Launch:** `Open Studio.vbs` → `Start-Studio.ps1`
- **Config:** `Studio.config.json`
- **Current Dashboard target:** `Creators\Studio\Open Studio.vbs`

## Planned Implementation
- **Exe name:** `Studio.exe`
- **Output path:** `Creators\C-Studio\build\Studio.exe`
- **Icon:** `H:\MystikStudio\Icons\Studio.ico`
- **Compile:** `csc.exe /target:winexe /win32icon:"H:\MystikStudio\Icons\Studio.ico"`
- **Dashboard target (future):** `Creators\C-Studio\build\Studio.exe`

## Known Inputs
- Character prompts (user input)
- Config: `Studio.config.json`
- ComfyUI workflow files

## Known Outputs
- Generated character images
- Character save data: `Studio-saves.json`
- Reports

## Rollback
- Original PowerShell files remain at `Creators\Studio\`
- Archive rollback docs at `Creators\archive\Studio-PowerShell\README.txt`
- Do not use as active Dashboard target until migration is complete.
