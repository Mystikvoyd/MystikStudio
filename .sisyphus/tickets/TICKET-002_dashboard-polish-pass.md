---
ticket_id:          TICKET-002
title:              Dashboard UI polish pass — layout, alignment, fonts, logo, overscan
type:               improvement
priority:           medium
severity:           minor
status:             in_progress
created:            2026-05-10 05:15
updated:            2026-05-10 05:45
reporter:           user
assignee:           unassigned
component:          dashboard
environment:        Start-MystikStudioDashboard.ps1 — WinForms split-panel
labels:
  - ui
  - dashboard
  - polish
---

## Description

The dashboard split-panel launcher is functionally working but needs a
UI polish pass across multiple areas. The layout feels rough, text runs
off-screen, and visual elements need tightening.

## Steps to Reproduce

1. Launch `Start-MystikStudioDashboard.ps1` (or `Open MystikStudio Dashboard.vbs`)
2. Observe the overall layout and appearance

## Expected Behavior

A polished, professional-looking launcher with proper spacing, readable
text, aligned buttons, and visual branding.

## Actual Behavior

Multiple rough edges (see items below).

## Specific Items

### Layout & Spacing
- General spacing inconsistencies between elements
- Button alignment is off — tools in the right panel need clean grid alignment
- Words/text are running off the screen (horizontal overflow in some areas)

### Visual / Branding
- Font sizes and colors feel unpolished — needs a pass on typography
- No logo/icon at the top of the window — should add the MystikStudio icon
- Window title bar is missing the application icon (should use one of the `.ico` files in `Icons/`)

### Functionality
- Missing functionality that would improve the experience (user to specify
  what specific features are missing)

### Architecture
- Potential for a better approach to how the dashboard functions overall
  (user to elaborate)

## Files Affected

- `Start-MystikStudioDashboard.ps1` — main dashboard script
- `Icons/Mytikvoyd Studios.ico` — likely candidate for title bar / logo

## Notes

User confirmed: "Dashboard works, needs polish."
All items listed here are initial observations — more may surface during the work.

## Progress

### Done (2026-05-10)
- **Tree text cutoff**: SplitterDistance increased from 160→240. Removed
  hardcoded `$tree.Width = 152`, now dynamically fills panel via
  `$leftPanel.ClientSize.Width - 8` + Anchor binding.
- **Form title bar icon**: Added `$form.Icon` using `Icons/Mytikvoyd Studios.ico`
- **Logo at top**: Header now includes a 32x32 PictureBox with the icon
- **Right panel dynamic width**: Removed AutoSize + hardcoded 390px min.
  Inner panel now uses Anchor + resize handler to fill the right panel.
  Section labels and separator also use Anchor = "Top, Left, Right" to stretch.
- **Form width**: Increased from 700→800 for more comfortable layout
- **Layout reorg**: CREATORS section now shows only the 2 generators
  (Character Generator, LoRA Tester). Added "CREATORS FOLDERS" sub-section
  (indented, smaller font) under CREATORS with Workflows, Output, Input —
  all using brown (#463728) folder color. COMFYUI section simplified to
  just Scripts (the only unique ComfyUI item). Added `Add-SubSection` function.

### Remaining
- Font sizes/colors need a style pass (button text, section headers)
- Tree usefulness still in question (user suggested buttons might replace it)
- Missing functionality and architectural improvements TBD
