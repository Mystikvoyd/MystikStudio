---
ticket_id:          TICKET-004
title:              Add 3rd column to dashboard — 4 new utility panels
type:               feature
priority:           medium
severity:           enhancement
status:             closed
created:            2026-05-10 07:30
updated:            2026-05-10 07:50
resolved:           2026-05-10 07:50
closed:             2026-05-10 07:50
reporter:           user
assignee:           unassigned
component:          dashboard
environment:        Start-MystikStudioDashboard.ps1
labels:
  - feature
  - layout
  - columns
---

## Description

Add a 3rd column to the right panel of the dashboard alongside
the existing 2 columns, bringing the total to 3 columns × 4 panels
= 12 panels. The new column provides quick-launch utility buttons
for ComfyUI, reports, development, and book resources.

## Design

### Layout Change
- Form width: 800 → 1000 to accommodate 3 columns
- Column count: 2 → 3
- Column width recalculation: `floor((rp.Width - 20) / 3)`
- 4 new panels in column 3

### New Feature: Arguments support in Add-PanelBox
The existing button system only supports `Start-Process $Target`
(file/folder) and `Start-Process $Target` (URL). Buttons like
"Open in VS Code" need `Start-Process code -ArgumentList $path`.
Add an optional `Arguments` field to the button data hashtable.

### Column 3 Distribution (4 new panels)

| Panel | Buttons | Action |
|-------|---------|--------|
| COMFYUI TOOLS | Open ComfyUI | URL → http://127.0.0.1:8000 |
| | ComfyUI Manager | URL → http://127.0.0.1:8000/manager |
| | ComfyUI Folder | Folder → ComfyUI root |
| REPORTS & SESSION | Reports Folder | Folder → ComfyUI\Reports |
| | Session Module | Folder → shared/ |
| | LoRA Config | File → lora-tester.config.json |
| DEVELOPMENT | Open in VS Code | Launch → code with studio root arg |
| | Open Terminal | Launch → powershell at studio root |
| | GitHub Issues | URL → repo issues page |
| BOOK RESOURCES | Manuscript | Folder → book-design/manuscript |
| | Reference | Folder → book-design/reference |
| | Assets | Folder → book-design/assets |

### Implementation Steps
1. Increase `$form.ClientSize` width 800 → 1000
2. Change column count to 3: `$colW = floor(($rp.Width - 20) / 3)`
3. Create `$col3` panel with Anchor="Top, Left, Right"
4. Add `Arguments` parameter to Add-PanelBox:
   `if ($a) { Start-Process -FilePath $t -ArgumentList $a }`
5. Define 4 new panels with button data
6. Push footer y past the tallest of all 3 columns

## Resolution

- Form widened to 1000, column count 2→3
- Added `Arguments` to `Add-PanelBox` for `Start-Process -ArgumentList` support
- Created 4 new panels in col 3: COMFYUI TOOLS, REPORTS & SESSION, DEVELOPMENT, BOOK RESOURCES
- Updated column height calculation for 3 columns

**Commit:** `b1e716a`  
**Repo:** https://github.com/Mystikvoyd/MystikStudio/commit/b1e716a
