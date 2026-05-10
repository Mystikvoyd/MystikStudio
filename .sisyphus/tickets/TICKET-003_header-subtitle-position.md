---
ticket_id:          TICKET-003
title:              Header subtitle "Modular Creative Toolkit" too close to title — overlaps top banner
type:               bug
priority:           low
severity:           cosmetic
status:             open
created:            2026-05-10 07:00
updated:            2026-05-10 07:00
reporter:           user
assignee:           unassigned
component:          dashboard
environment:        Start-MystikStudioDashboard.ps1 — right panel header
labels:
  - ui
  - header
  - layout
---

## Description

The subtitle "Modular Creative Toolkit" in the dashboard header is
positioned too close to the "MystikStudio" title. The subtitle appears
to sit under/behind the top banner area with inadequate vertical
separation, making it look cramped and cut off.

## Steps to Reproduce

1. Launch `Start-MystikStudioDashboard.ps1`
2. Look at the header area at the top of the right panel

## Expected Behavior

The "Modular Creative Toolkit" subtitle should be clearly separated
below the "MystikStudio" title with comfortable vertical spacing,
sitting below the top banner area, not within it.

## Actual Behavior

The subtitle starts at Top=30 inside the header panel, only ~4px below
the bottom of the 16pt title text. This makes it appear to overlap
or be tucked under the title banner.

## Root Cause Analysis

The header panel has `$subLbl.Top = 30` while the 16pt bold title
text occupies roughly y=4 to y=26 (font height ~22px). The 4px gap
between title bottom and subtitle top is insufficient visual separation.

## Resolution

**Commit:** (pending)  
**Repo:** (pending)

## Files Affected

- `Start-MystikStudioDashboard.ps1` — adjust subtitle Top and header height

## Notes

Fixed by increasing `$subLbl.Top` from 30 to 38 (12px gap below title
instead of 4px), and increasing `$hdr.Height` from 64 to 72 to
accommodate the taller header content. Post-header y gap also increased
72→80 for consistent spacing.
