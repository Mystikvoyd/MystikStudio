# CURSOR — Current State

**Last updated:** 2026-05-10 06:30
**Session focus:** 2-column panel layout — 8 GroupBox panels in 2 columns

---

## Active Context

Working on TICKET-002 dashboard polish. Right panel completely restructured
into 2-column panel layout:

**Column 1 (4 panels):** CREATORS, CREATORS FOLDERS, COMFYUI, LINKS
**Column 2 (4 panels):** WEB APPS, PROJECT·DESIGN, PROJECT·DATA, PROJECT·MODELS

Each panel is a GroupBox with a titled border containing stacked full-width
buttons. Header Y offset bumped to 12 to prevent title bar cutoff.

Remaining: fine-tuning panel sizing/spacing, fonts/colors refinement.

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
