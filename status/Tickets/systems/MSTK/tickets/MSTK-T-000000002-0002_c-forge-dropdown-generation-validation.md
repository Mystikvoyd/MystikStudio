# MSTK-T-000000002-0002: C-Forge dropdown and generation validation

Ticket ID: MSTK-T-000000002-0002
Title: C-Forge dropdown and generation validation
System: MSTK
Type: Audit
Status: Blocked
Priority: P2
Owner: Leonardo
Created: 2026-05-14
Updated: 2026-05-14
Parent: MSTK-T-000000002-0000
Stub: 0002
Related tickets: MSTK-T-000000002-0000, MSTK-T-000000002-0001, MSTK-B-000000003-0000
Repo: Mystikvoyd/MystikStudio
Branch: master
Local path: H:\MystikStudio

## Summary

Validate the remaining C-Forge runtime items not proven by the accepted redo package for `MSTK-T-000000002-0001`.

## Reason

The C-Forge main UI evidence was accepted, but dropdown-open evidence and generation remain unverified. A later user-provided screenshot shows checkpoint population is working, but layout and startup/window behavior still need repair before generation validation should continue.

## Scope

- Verify checkpoint/model dropdown population in the running C-Forge UI.
- If ComfyUI is already running and safe to use, run one simple image generation test.
- Capture evidence in screenshots and a ZIP report package.

## Out of Scope

- Do not modify Forge source under this validation ticket.
- Do not stage Forge source under this validation ticket.
- Do not commit Forge source under this validation ticket.
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
5. No source files are changed, staged, or committed under this validation ticket.
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

## Validation Attempt 2026-05-14 A

Uploaded ZIP contained:

- `Forge_Runtime_CheckpointDropdownOpen.png`
- `Leo Reports.txt`
- `ticket.txt`

Result: Needs Redo.

Reason: The screenshot named `Forge_Runtime_CheckpointDropdownOpen.png` showed the desktop, not the running C-Forge window or an opened checkpoint dropdown. The report also stated dropdown population was NOT VERIFIED and generation was skipped.

## Validation Attempt 2026-05-14 B

Uploaded ZIP contained:

- `Forge_Runtime_CheckpointDropdownOpen.png`
- `Leo Reports.txt`
- `ticket.txt`

Result: Needs Redo.

Reason: The screenshot again showed the desktop rather than the C-Forge window or an opened checkpoint dropdown. The report stated build PASS and launch PASS, but dropdown population stayed NOT VERIFIED and generation was skipped. This does not satisfy the screenshot evidence requirement.

## Manual Screenshot Review 2026-05-14

User manually provided a screenshot of the running C-Forge window.

Result: Blocked by `MSTK-B-000000003-0000`.

Observed:

- C-Forge window is visible.
- ComfyUI status bar shows online.
- Checkpoint control is visible.
- Checkpoint value is populated as `SDXL\\dreamshaperXL_lightningDPMSDE.safetensors`.
- Checkpoint population is visually proven at least for selected value.
- Dropdown list is not open.
- UI layout is cramped compared with C-Lab.
- Seed, Steps, CFG, Width, Height region is cramped and labels are difficult to read.
- Three LoRA rows are visible, but labels and enable checkboxes are cramped.
- User wants Forge to follow the working C-Lab layout pattern.
- User reports Forge opens near the cursor and then closes, indicating launch position or startup behavior may also need correction.

Related bug ticket:

`MSTK-B-000000003-0000`

## Files Changed

This ticket file only.

## Files Not To Touch

- Fusion files
- Dashboard targets
- Forge source files unless working the related bug ticket
- Forge binary files unless rebuilt locally by the build script
- Config files unless explicitly needed for position persistence

## Risks

Generation validation may fail or be misleading while layout and startup/window behavior remain unstable.

## Rollback Plan

No source changes are expected under this ticket. If this ticket is wrong, mark it Open and remove the bug dependency.

## Current Result

Blocked by `MSTK-B-000000003-0000`.

## Next Action

Fix C-Forge layout parity and startup positioning in `MSTK-B-000000003-0000`, then return to this validation ticket for generation validation closure.

## Close Criteria

Close when dropdown population is directly verified or explicitly marked failed, and generation is tested or explicitly skipped with reason.
