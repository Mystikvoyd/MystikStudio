# CURSOR — Current State

**Last updated:** 2026-05-10 07:50
**Session focus:** 3rd column added — 12 panels in 3 columns

---

## Active Context

Dashboard now has 3 columns with 12 panels total.

**Column 1:** CREATORS, CREATORS FOLDERS, COMFYUI, LINKS
**Column 2:** WEB APPS, PROJECT·DESIGN, PROJECT·DATA, PROJECT·MODELS
**Column 3:** COMFYUI TOOLS, REPORTS & SESSION, DEVELOPMENT, BOOK RESOURCES

Form width expanded to 1000. Add-PanelBox now supports optional `Arguments`
field for launching with args (VS Code, Terminal).

### Completed (TICKET-004)
- 3rd column with 4 utility panels added
- Arguments support for panel buttons
- Form widened from 800→1000

### Remaining
- TICKET-002: fine-tuning panel sizing/spacing if needed

## Decisions Made

- Project structure: tools in `Creators/`, web tools in `webpage/`, shared modules
  in `shared/`, book assets in `book-design/`
- Dashboard uses `tool.json` auto-discovery — no hardcoded tool list
- Dashboard layout: split-panel with folder tree (left) + tool buttons (right)
- LoRA session reports use Python (not PowerShell) for file I/O to avoid path issues
- .sisyphus context system adopted for LLM session continuity
- Ticket system uses full IT-style frontmatter (type, priority, severity,
  component, environment, labels, link chains, timestamps, ownership)
- Continuation: closed tickets get `continued_in`, new tickets get `continues`
  — numbers never reused

## Known Issues

- Tree may not be useful given buttons already cover navigation (user's comment)
- Font sizes/colors still need a style pass
- Button alignment could be cleaner
- Missing functionality and architectural improvements not yet explored

## Next Likely Steps

1. User tests the dashboard changes
2. Continue TICKET-002 polish items

## Pinned Tickets

- `TICKET-001` — closed: Initialize .sisyphus context/knowledge system
- `TICKET-002` — **open**: Dashboard UI polish pass (layout, alignment, fonts, logo, overscan)
