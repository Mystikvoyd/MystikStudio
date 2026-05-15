# MSTK-T-000000002-0002: C-Forge dropdown and generation validation

Ticket ID: MSTK-T-000000002-0002
Title: C-Forge dropdown and generation validation
System: MSTK
Type: Audit
Status: Open
Priority: P2
Owner: Leonardo
Created: 2026-05-14
Updated: 2026-05-14
Parent: MSTK-T-000000002-0000
Stub: 0002
Related tickets: MSTK-T-000000002-0000, MSTK-T-000000002-0001
Repo: Mystikvoyd/MystikStudio
Branch: master
Local path: H:\MystikStudio

## Summary

Validate the remaining C-Forge runtime items not proven by the accepted redo package for `MSTK-T-000000002-0001`.

## Reason

The C-Forge main UI evidence was accepted, but checkpoint dropdown population and generation remain NOT VERIFIED.

## Scope

- Verify checkpoint/model dropdown population in the running C-Forge UI.
- If ComfyUI is already running and safe to use, run one simple image generation test.
- Capture evidence in screenshots and a ZIP report package.

## Out of Scope

- Do not modify Forge source.
- Do not stage Forge source.
- Do not commit Forge source.
- Do not touch Fusion.
- Do not rebuild Fusion.
- Do not change Dashboard targets.
- Do not move model files.
- Do not change configs unless generation requires normal runtime UI selection.

## Acceptance Criteria

1. Screenshot shows the checkpoint dropdown opened or populated.
2. Report states dropdown population as PASS, FAIL, or NOT VERIFIED.
3. If generation is tested, report records PASS or FAIL and the output evidence path.
4. If generation is skipped, report clearly states why.
5. No source files are changed, staged, or committed.
6. ZIP package includes report, screenshots, and ticket.txt.
7. ZIP filename starts with this ticket ID.

## Validation Steps

1. Pull latest master.
2. Build C-Forge only.
3. Launch C-Forge.
4. Bring Forge to the front.
5. Open the checkpoint/model dropdown and capture it.
6. Check whether ComfyUI is running at `http://127.0.0.1:8000/system_stats`.
7. If ComfyUI is running, run one safe simple generation test.
8. Package report and screenshots into a ZIP under the Leonardo Prompts Reports folder.

## Evidence

Expected ZIP path:

`C:\Users\Michael\Documents\Leonardo Prompts\Reports\MSTK-T-000000002-0002_C-Forge-Dropdown-Generation-Validation.zip`

Expected screenshots:

- `Forge_Runtime_CheckpointDropdownOpen.png`
- `Forge_Runtime_GenerationResult.png` if generation is tested

## Files Changed

This ticket file only.

## Files Not To Touch

- Fusion files
- Dashboard targets
- Forge source files
- Forge binary files unless rebuilt locally by the build script
- Config files

## Risks

Generation may fail because of ComfyUI availability, model mismatch, or worker wiring. Any failure should be recorded rather than hidden.

## Rollback Plan

No source changes are expected. If this ticket is wrong, mark it Cancelled rather than deleting it.

## Current Result

Open.

## Next Action

Run dropdown and generation validation through Leonardo/OpenCode.

## Close Criteria

Close when dropdown population is directly verified or explicitly marked failed, and generation is tested or explicitly skipped with reason.
