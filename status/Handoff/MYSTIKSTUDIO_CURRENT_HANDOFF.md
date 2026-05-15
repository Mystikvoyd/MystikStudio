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
Status: Build Fix Passed - Needs Visual Review
Priority: P2

Build blocker fix completed:

1. The missing Forge.ico build blocker has been fixed.
2. `Build-CForge.ps1` now treats `Icons\Forge.ico` as optional.
3. `Forge.cs` now catches runtime icon load failure.
4. Build passed with and without the icon file.
5. Launch passed.
6. Remaining work: visual review, layout polish, and generation validation.

### `MSTK-T-000000002-0002`

Title: C-Forge dropdown and generation validation
Type: Audit
Status: Needs Validation

Previously blocked by MSTK-B-000000003-0000 build failure.
Build blocker is now resolved. Validation can proceed.

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
- Build blocker (missing Forge.ico) has been fixed. Build now passes with and without icon.

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

Work tickets:

`MSTK-B-000000003-0000` — Remaining: visual review, layout polish, generation validation
`MSTK-T-000000002-0002` — Generation validation, no longer blocked by build

Build blocker is resolved. Next session should continue with visual review and generation tests.

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

## Ticket Numbering Rule

Ticket numbers use per-type independent sequences: `MSTK-[TYPE]-[TYPE-SEQUENCE]-[CHILD-SEQUENCE]`. Each type (B, T, M, etc.) has its own counter. See `status/Tickets/TICKET_STANDARD.md` for the full rule.

## Standing Report Packaging Rule

Every ticket or child ticket worked by an agent must produce a zip package in:
`C:\Users\Michael\Documents\Leonardo Prompts\Reports`

The zip filename must be the exact ticket number: `[TICKET-NUMBER].zip`

The zip must include:
1. Every reviewed source or script file the reviewer needs to inspect.
2. The current Leo Reports.txt file.
3. Any ticket or handoff file changed during the work.
4. Any validation output file if one was created.

The zip must exclude:
1. Executables such as Forge.exe, Lab.exe, and Fusion.exe.
2. bin and obj folders.
3. Model files.
4. Config files.
5. Generated build output.
6. Unrelated files.

Every final Leo report must include:
- Ticket: [exact ticket number]
- Stub: [stub or child ticket number if applicable]
- Status: [PASS, FAIL, BLOCKED, NEEDS REVIEW, or PACKAGED]
- Zip created: path to zip
- Zip contents verified: [list exact files inside]
- Upload back to ChatGPT: [list exact files]

If work continues under a parent ticket without a child ticket, use the parent ticket number for the zip.

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


## Ticket Template Rule

MystikStudio ticket rules now treat TICKET_TEMPLATE.md as the canonical ongoing ticket format. TICKET_STANDARD.md must include or reflect the same template. If the template changes then the ticket standard must be reviewed and updated.



MSTK-M-000000006-0000 committed at 3aa4bbd. MSTK-M-000000006-0001 created for status hygiene.


### MSTK-F-000000001-0000
Title: Lab and Forge fixed seed UI freeze repair
Type: Bug (F type)
Status: Packaged for Review
Lab generation moved to background thread. Forge already async.

### MSTK-F-000000001-0002
Title: Config save/load and workflow image reference repair
Status: Packaged for Review

### MSTK-F-000000001-0003
Title: Config load default config and workflow image state
Status: Packaged for Review

### MSTK-F-000000001-0004
Title: Restore icon source assets
Status: Committed and Pushed

### MSTK-F-000000001-0005
Title: Replace placeholder icons with real source assets
Status: Committed and Pushed

