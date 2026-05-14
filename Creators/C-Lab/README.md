# C-Lab — Future C# Migration Scaffold

**Status:** Scaffold only — not an active Dashboard target.

## Purpose
Future C# counterpart for the current PowerShell Lab app.

## PowerShell Source App
- **Name:** Lab
- **Location:** `H:\MystikStudio\Creators\Lab`
- **Launch:** `Open Lab.vbs` → `Start-Lab.ps1`
- **Config:** `Lab.config.json`
- **Current Dashboard target:** `Creators\Lab\Open Lab.vbs`

## Planned Implementation
- **Exe name:** `Lab.exe`
- **Output path:** `Creators\C-Lab\build\Lab.exe`
- **Icon:** `H:\MystikStudio\Icons\Lab.ico`
- **Compile:** `csc.exe /target:winexe /win32icon:"H:\MystikStudio\Icons\Lab.ico"`
- **Dashboard target (future):** `Creators\C-Lab\build\Lab.exe`

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
- Do not use as active Dashboard target until migration is complete.
