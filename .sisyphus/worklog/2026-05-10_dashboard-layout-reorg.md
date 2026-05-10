# Worklog: 2026-05-10

## Session 5 — Dashboard Layout Reorganization

**Goal:** Restructure dashboard sections per user feedback — separate generators
from folders, add sub-section, consolidate ComfyUI.

### What was done

- Added `Add-SubSection` function — indented, smaller/darker label for grouped items
- **CREATORS section**: Now only shows the 2 generator tool launchers
  (Character Generator, LoRA Tester). Filters out folder-type tools.
- **CREATORS FOLDERS sub-section**: New indented group under CREATORS with
  ComfyUI Workflows, ComfyUI Output, ComfyUI Input — all using brown (#463728)
  as the folder link color.
- **COMFYUI section**: Simplified to just Scripts (Workflows moved to CREATORS
  FOLDERS, Output/Input already there).
- Updated TICKET-002 with progress.

**Commit:** `366e14d` — pushed to `origin/master`
