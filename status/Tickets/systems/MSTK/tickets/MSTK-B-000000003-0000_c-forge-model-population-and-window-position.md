# MSTK-B-000000003-0000: C-Forge Lab layout parity and window behavior

Ticket ID: MSTK-B-000000003-0000
Title: C-Forge Lab layout parity and window behavior
System: MSTK
Type: Bug
Status: Open
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

C-Forge launches and the user-provided screenshot now shows the checkpoint field populated with `SDXL\\dreamshaperXL_lightningDPMSDE.safetensors`. That means checkpoint population is no longer the primary blocker.

The remaining problem is that Forge needs to match the working C-Lab layout and runtime behavior. The current Forge screenshot shows cramped controls, label wrapping, bottom controls crowded into the lower-left area, and unreliable window placement/capture behavior. The user reports Forge opens where the cursor is and then closes. The app should open maximized or on the primary display, or restore its last valid closed position.

## Reason

Validation ticket `MSTK-T-000000002-0002` could not be closed cleanly because Leo repeatedly captured the desktop instead of the Forge window, generation remains unverified, and the UI still needs layout parity with Lab before committing C-Forge source as stable.

## Scope

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

1. C-Forge opens maximized on the primary display or restores a valid last closed position.
2. C-Forge does not open off-screen or behind unrelated windows during validation.
3. C-Forge layout follows the working C-Lab layout pattern where applicable.
4. Bottom command buttons are visible and not crowded.
5. Seed, Steps, CFG, Width, Height, Sampler, and Scheduler controls are readable and not clipped.
6. Forge has three LoRA dropdowns, three enable checkboxes, and three strength controls.
7. LoRA controls are aligned and readable.
8. Model scan log records the checkpoint search path.
9. Model scan log records the number of checkpoint files found.
10. Checkpoint dropdown contains actual checkpoint entries when files exist.
11. The selected checkpoint after populate is logged.
12. Evidence screenshots must be visually reviewed by the user or ChatGPT, not only by Leo file existence checks.
13. Generation validation can be retried through `MSTK-T-000000002-0002` after this bug is resolved.

## Validation Steps

1. Pull latest master.
2. Compare C-Lab layout code to C-Forge layout code.
3. Apply layout/window behavior changes to C-Forge only.
4. Build C-Forge only.
5. Launch C-Forge.
6. Confirm app opens maximized on the primary display or a valid restored position.
7. Confirm checkpoint dropdown is populated.
8. Confirm all required controls are visible and readable.
9. Capture a screenshot for visual review.
10. Return to `MSTK-T-000000002-0002` for generation validation closure.

## Evidence

User-provided screenshot shows:

- C-Forge window visible.
- ComfyUI online in status bar.
- Checkpoint control visible.
- Checkpoint value populated as `SDXL\\dreamshaperXL_lightningDPMSDE.safetensors`.
- Three LoRA rows are present, but layout is cramped.
- LoRA enable labels wrap awkwardly.
- Seed, Steps, CFG, Width, Height region is cramped and label readability is poor.
- Bottom command buttons are crowded in the lower-left command bar.
- Dropdown list is not open.
- Generation is not verified.

## Files Changed

This ticket file only.

## Files Not To Touch

- Fusion files
- Dashboard targets
- Model files
- Config files unless explicitly needed for position persistence

## Risks

If this is ignored, C-Forge source may be committed while layout, window positioning, and generation remain unstable or unverified.

## Rollback Plan

If the diagnosis shows no bug, mark this ticket Closed with evidence and return to the validation ticket.

## Current Result

Open.

## Next Action

Dispatch Leo to align C-Forge with the C-Lab layout pattern, fix startup positioning, and preserve verified checkpoint population.

## Close Criteria

Close when C-Forge reliably opens on the primary display or valid restored position, layout matches Lab usability, required LoRA/model controls are visible, and checkpoint population remains working.
