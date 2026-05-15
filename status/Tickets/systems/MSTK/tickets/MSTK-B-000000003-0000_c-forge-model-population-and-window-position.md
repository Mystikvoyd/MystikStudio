# MSTK-B-000000003-0000: C-Forge Lab layout parity and window behavior

Ticket ID: MSTK-B-000000003-0000
Title: C-Forge Lab layout parity and window behavior
System: MSTK
Type: Bug
Status: Build Blocked
Priority: P1
Owner: Leonardo
Created: 2026-05-14
Updated: 2026-05-14
Parent: MSTK-B-000000003-0000
Stub: 0000
Related tickets: MSTK-T-000000002-0000, MSTK-T-000000002-0002
Repo: Mystikvoyd/MystikStudio
Branch: master
Local path: H:\MystikStudio

## Summary

C-Forge launches from the existing local executable and the user-provided screenshot shows the checkpoint field populated with `SDXL\\dreamshaperXL_lightningDPMSDE.safetensors`. That means checkpoint population is no longer the primary blocker.

The current blocker is that C-Forge cannot be cleanly rebuilt from the fresh repo because the build script references a missing icon path: `H:\MystikStudio\Icons\Forge.ico`. Until the icon dependency is fixed, screenshots may be from an older local executable rather than the newly built source.

The remaining layout problem is that Forge needs to match the working C-Lab layout and runtime behavior. The current Forge screenshot shows cramped controls, label clipping, bottom controls crowded into the lower-left area, and unreliable window placement/capture behavior. The app should open maximized or on the primary display, or restore its last valid closed position.

## Reason

Validation ticket `MSTK-T-000000002-0002` could not be closed cleanly because Leo repeatedly captured the desktop instead of the Forge window, generation remains unverified, and the UI still needs layout parity with Lab before committing C-Forge source as stable.

A manual user run then showed the C-Forge build failed with:

`Creators\C-Forge\Forge.exe: error CS1567: Error generating Win32 resource: Error reading icon 'h:\MystikStudio\Icons\Forge.ico' -- The system cannot find the file specified.`

## Scope

- Fix C-Forge build so a fresh clone can build without requiring an untracked local icon file.
- Prefer a safe Build-CForge.ps1 fallback: if `Icons\Forge.ico` exists, use it; if missing, build without the icon and log a warning.
- Compare `Creators/C-Lab/Lab.cs` layout behavior against `Creators/C-Forge/Forge.cs`.
- Bring C-Forge layout up to the same working pattern as C-Lab where applicable.
- Fix C-Forge startup position so it opens maximized on the primary display or restores a valid last closed position.
- If saved position is off-screen or invalid, reset to the primary display center/maximized state.
- Keep the bottom command buttons visible and not crowded.
- Make Seed, Steps, CFG, Width, Height, Sampler, and Scheduler labels readable and not clipped.
- Ensure Forge has three LoRA dropdowns, three enable checkboxes, and three strength controls.
- Ensure the LoRA controls are aligned and readable.
- Keep the Models checkpoint dropdown visible and populated when checkpoint files exist.
- Add runtime logging sufficient to prove model scan result and selected checkpoint.

## Out of Scope

- Do not touch Fusion.
- Do not rebuild Fusion.
- Do not change Dashboard targets.
- Do not point Dashboard at C# Lab or C# Forge.
- Do not move model files.
- Do not delete files.

## Acceptance Criteria

1. C-Forge builds successfully from a clean clone even when `H:\MystikStudio\Icons\Forge.ico` is missing.
2. If icon exists, Build-CForge.ps1 uses it.
3. If icon is missing, Build-CForge.ps1 logs a warning and builds without it.
4. C-Forge opens maximized on the primary display or restores a valid last closed position.
5. C-Forge does not open off-screen or behind unrelated windows during validation.
6. C-Forge layout follows the working C-Lab layout pattern where applicable.
7. Bottom command buttons are visible and not crowded.
8. Seed, Steps, CFG, Width, Height, Sampler, and Scheduler controls are readable and not clipped.
9. Forge has three LoRA dropdowns, three enable checkboxes, and three strength controls.
10. LoRA controls are aligned and readable.
11. Model scan log records the checkpoint search path.
12. Model scan log records the number of checkpoint files found.
13. Checkpoint dropdown contains actual checkpoint entries when files exist.
14. The selected checkpoint after populate is logged.
15. Evidence screenshots must be visually reviewed by the user or ChatGPT, not only by Leo file existence checks.
16. Generation validation can be retried through `MSTK-T-000000002-0002` after this bug is resolved.

## Validation Steps

1. Pull latest master.
2. Fix the C-Forge icon build dependency.
3. Compare C-Lab layout code to C-Forge layout code.
4. Apply layout/window behavior changes to C-Forge only.
5. Build C-Forge only.
6. Launch C-Forge.
7. Confirm app opens maximized on the primary display or a valid restored position.
8. Confirm checkpoint dropdown is populated.
9. Confirm all required controls are visible and readable.
10. Capture a screenshot for visual review.
11. Return to `MSTK-T-000000002-0002` for generation validation closure.

## Evidence

User-provided screenshot shows:

- C-Forge window visible.
- ComfyUI online in status bar.
- Checkpoint control visible.
- Checkpoint value populated as `SDXL\\dreamshaperXL_lightningDPMSDE.safetensors`.
- Three LoRA rows are present, but layout is cramped.
- LoRA enable labels are visible but awkward.
- Seed, Steps, CFG, Width, Height region remains cramped and label readability is poor.
- Bottom command buttons are crowded in the lower-left command bar.
- Dropdown list is not open.
- Generation is not verified.

User terminal output shows:

- `git status --short` includes `M Creators/C-Forge/Forge.cs` and `M Creators/C-Forge/Forge.exe`.
- C-Forge build failed because `H:\MystikStudio\Icons\Forge.ico` is missing.
- `Start-Process .\Creators\C-Forge\Forge.exe` launched the existing executable after the failed build, so the screenshot is not proof of the latest source build.

## Local Fix Report 2026-05-14

Leonardo reports local source changes in `Creators/C-Forge/Forge.cs` only.

Reported changes:

- Forge opens maximized by default.
- Window position persistence saves and restores maximized state and normal position.
- Off-screen detection added for restored normal position.
- Generation tab layout rebuilt to match C-Lab row structure.
- Row 1: Seed, Random, Width, Height.
- Row 2: Steps, CFG, Sampler, Scheduler.
- Row 3: Workflow Preset.
- Models group preserved.
- ControlNet group preserved.
- LoRA rows widened and aligned.
- Numeric controls use white background and black text.

Manual validation found the build failed due missing icon, so the reported Build PASS / Launch PASS should not be accepted until repeated after the icon build dependency is fixed.

Files staged or committed by Leonardo: None.

## Files Changed

Ticket file updated by ChatGPT.

Local pending source changes reported or observed:

- `Creators/C-Forge/Forge.cs`
- `Creators/C-Forge/Forge.exe` from local build/output state
- `Creators/C-Lab/Lab.default.json`
- `Creators/C-Lab/Lab.exe`

## Files Not To Touch

- Fusion files
- Dashboard targets
- Model files
- Config files unless explicitly needed for position persistence

## Risks

If this is committed without fixing the icon build dependency and visual review, C-Forge may still have build, layout, or positioning problems.

## Rollback Plan

If visual review fails, keep the source uncommitted and send Leonardo a targeted correction prompt. If build fix fails, leave C-Forge uncommitted and restore only with explicit user approval.

## Current Result

Build Blocked by missing icon dependency.

## Next Action

Dispatch Leonardo to fix the Build-CForge.ps1 icon dependency first, then rebuild C-Forge and continue layout correction.

## Close Criteria

Close when C-Forge builds from a clean clone, reliably opens on the primary display or valid restored position, layout matches Lab usability, required LoRA/model controls are visible, and checkpoint population remains working.
