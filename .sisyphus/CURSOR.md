# CURSOR — Current State

**Last updated:** 2026-05-10 06:00
**Session focus:** Dashboard layout reorg — generators vs folders, sub-section

---

## Active Context

Working on TICKET-002 dashboard polish. Layout reorganization done:

1. **CREATORS**: only the 2 generators (Character Generator, LoRA Tester)
2. **CREATORS FOLDERS** sub-section (indented): Workflows, Output, Input (brown)
3. **COMFYUI** section: Scripts only
4. Added `Add-SubSection` function (indented, smaller/darker label)

Remaining polish: fonts/colors style pass, tree usefulness question,
missing functionality, architectural improvements.

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
