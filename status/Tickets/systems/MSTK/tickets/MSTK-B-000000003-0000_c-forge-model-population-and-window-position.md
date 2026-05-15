# MSTK-B-000000003-0000: C-Forge model population and window position

Ticket ID: MSTK-B-000000003-0000
Title: C-Forge model population and window position
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

C-Forge launches and shows ComfyUI online, but the checkpoint dropdown currently displays `None` in the user-provided screenshot. Dropdown population and generation validation are blocked until model population is verified or fixed.

The user also reports Forge opens near the cursor and then closes. The app should open on the main screen or restore its last valid closed position to make validation and normal use reliable.

## Reason

Validation ticket `MSTK-T-000000002-0002` could not be closed. Evidence shows the C-Forge window, but not an opened/populated checkpoint dropdown. The visible selected checkpoint value is `None`.

## Scope

- Diagnose why the C-Forge checkpoint dropdown shows `None` after a clean clone and build.
- Confirm the model root used by C-Forge.
- Confirm checkpoint scan path includes `C:\Users\Michael\Documents\ComfyUI\models\checkpoints`.
- Confirm available checkpoint files are detected and shown.
- Fix C-Forge startup position so it opens on the primary display or restores last valid screen position.
- Add runtime logging sufficient to prove model scan result and selected checkpoint.

## Out of Scope

- Do not touch Fusion.
- Do not rebuild Fusion.
- Do not change Dashboard targets.
- Do not point Dashboard at C# Lab or C# Forge.
- Do not move model files.
- Do not delete files.

## Acceptance Criteria

1. C-Forge opens on the primary display or restores a valid last closed position.
2. C-Forge does not open off-screen or behind unrelated windows during validation.
3. Model scan log records the checkpoint search path.
4. Model scan log records the number of checkpoint files found.
5. Checkpoint dropdown contains actual checkpoint entries when files exist.
6. If no checkpoint files are found, the UI and log clearly explain the missing path.
7. C-Forge generation validation can be retried after this bug is resolved.
8. Evidence screenshots must be visually reviewed by the user or ChatGPT, not only by Leo file existence checks.

## Validation Steps

1. Pull latest master.
2. Build C-Forge only.
3. Launch C-Forge.
4. Confirm app opens on primary display or valid restored position.
5. Confirm checkpoint dropdown is populated or log explains why it is not.
6. Capture screenshot of opened dropdown after fix.
7. Return to `MSTK-T-000000002-0002` for validation closure.

## Evidence

User-provided screenshot shows:

- C-Forge window visible.
- ComfyUI online in status bar.
- Checkpoint control visible.
- Checkpoint value is `None`.
- Dropdown list is not open.

## Files Changed

This ticket file only.

## Files Not To Touch

- Fusion files
- Dashboard targets
- Model files
- Config files unless explicitly needed for position persistence

## Risks

If this is ignored, C-Forge source may be committed while model selection and generation remain unverified.

## Rollback Plan

If the diagnosis shows no bug, mark this ticket Closed with evidence and return to the validation ticket.

## Current Result

Open.

## Next Action

Dispatch Leo to diagnose C-Forge model population and add primary-display or last-valid-position startup behavior.

## Close Criteria

Close when C-Forge reliably populates checkpoint choices or provides a clear logged reason why it cannot, and the window opens in a reliable visible location.
