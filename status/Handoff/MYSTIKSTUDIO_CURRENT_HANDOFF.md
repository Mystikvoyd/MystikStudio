# MystikStudio Current Handoff

Last updated: 2026-05-14
Repo: `Mystikvoyd/MystikStudio`
Branch: `master`
Primary local repo: `H:\MystikStudio`
Current local state reported by user: fresh clean clone was created, then Leonardo made local C-Forge source changes.

## Start Here

Next session should read this file first, then read:

1. `status/Handoff/MYSTIKSTUDIO_HANDOFF.md`
2. `status/Tickets/TICKET_STANDARD.md`
3. `status/Tickets/systems/MSTK/MSTK_TICKET_LEDGER.md`
4. `status/Tickets/systems/MSTK/tickets/MSTK-B-000000003-0000_c-forge-model-population-and-window-position.md`
5. `status/Tickets/systems/MSTK/tickets/MSTK-T-000000002-0002_c-forge-dropdown-generation-validation.md`

## Current Ticket State

### `MSTK-B-000000003-0000`

Title: C-Forge Lab layout parity and window behavior
Type: Bug
Status: Build Blocked
Priority: P1

Current blocker:

C-Forge build fails on a fresh clone because `Build-CForge.ps1` references a missing icon:

`H:\MystikStudio\Icons\Forge.ico`

Observed build error:

`Creators\C-Forge\Forge.exe: error CS1567: Error generating Win32 resource: Error reading icon 'h:\MystikStudio\Icons\Forge.ico' -- The system cannot find the file specified.`

This means the Forge window screenshot after the build failure came from the existing local `Forge.exe`, not a newly validated build.

### `MSTK-T-000000002-0002`

Title: C-Forge dropdown and generation validation
Type: Audit
Status: Blocked

Blocked by:

`MSTK-B-000000003-0000`

Do not continue generation validation until the C-Forge build blocker is resolved and the updated source builds cleanly.

## Latest Local Findings

User-provided screenshot after local run showed:

- Forge opens.
- Forge is visible on screen.
- ComfyUI status bar shows online.
- Checkpoint is populated with `SDXL\dreamshaperXL_lightningDPMSDE.safetensors`.
- Three LoRA rows exist.
- ControlNet section exists.
- Bottom buttons exist.
- Layout is still cramped.
- Seed, Steps, CFG, Width, Height area is hard to read.
- LoRA checkbox labels/spacing still need polish.
- Build did not pass because of the missing icon.

## Current Dirty Local Files Last Reported

After user pulled and built, `git status --short` showed:

```text
 M Creators/C-Forge/Forge.cs
 M Creators/C-Forge/Forge.exe
 M Creators/C-Lab/Lab.default.json
 M Creators/C-Lab/Lab.exe
```

Important:

- `Creators/C-Forge/Forge.cs` contains Leonardo's local layout/window behavior changes.
- `Creators/C-Forge/Forge.exe` is a local build artifact and should not be staged yet.
- `Creators/C-Lab/Lab.default.json` and `Creators/C-Lab/Lab.exe` are unrelated local drift and should not be staged.

## Required Next Work

Work ticket:

`MSTK-B-000000003-0000`

Immediate task:

Fix `Creators/C-Forge/Build-CForge.ps1` so the icon is optional.

Required build behavior:

1. If `H:\MystikStudio\Icons\Forge.ico` exists, build with `/win32icon`.
2. If the icon is missing, print a warning and build without `/win32icon`.
3. Clean clone must build successfully without the icon file.

Then rebuild and launch C-Forge.

Only after the build passes should visual review continue.

## Hard Rules

- Do not touch Fusion.
- Do not rebuild Fusion.
- Do not change Dashboard targets.
- Do not point Dashboard at C# Lab or C# Forge.
- Do not move model files.
- Do not delete files.
- Do not run `git restore`.
- Do not run `git clean`.
- Do not stage `Forge.exe`.
- Do not stage Lab files.
- Do not stage config files.
- Do not claim visual PASS from screenshot file existence.
- Screenshots require user or ChatGPT visual review.

## Commands Next Session Should Use First

```powershell
Set-Location "H:\MystikStudio"
git pull origin master
git log -8 --oneline
git status --short
git diff --stat
git diff -- Creators/C-Forge/Build-CForge.ps1
git diff -- Creators/C-Forge/Forge.cs
```

## Build Test Command

```powershell
powershell -ExecutionPolicy Bypass -File ".\Creators\C-Forge\Build-CForge.ps1" -SignMode Dev
```

## Launch Command

```powershell
Start-Process ".\Creators\C-Forge\Forge.exe"
```

## Expected Report Location

Leonardo should write final report to:

`C:\Users\Michael\Documents\Leonardo Prompts\Leo Reports.txt`

## Next Commit Guidance

Do not commit yet.

Likely later source commit should include only:

- `Creators/C-Forge/Build-CForge.ps1`
- `Creators/C-Forge/Forge.cs`

Only if:

1. Build passes after icon fallback fix.
2. Visual review passes.
3. User explicitly approves commit.

Do not include:

- `Creators/C-Forge/Forge.exe`
- `Creators/C-Lab/Lab.exe`
- `Creators/C-Lab/Lab.default.json`
- Fusion files
- Dashboard files
- report ZIPs
