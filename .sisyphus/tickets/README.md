# Ticket System — IT-Style Issue Tracking

Each ticket is a single `.md` file. The system mimics enterprise IT ticketing
(Jira, ServiceNow, Zendesk) but lives entirely in the repo as flat files.

---

## Naming Convention

```
MVS-NNNNNNNNN_kebab-case-title.md
```

Examples: `MVS-000000042_dashboard-splitter-not-rendering.md`

---

## Ticket Template

```yaml
---
ticket_id:          MVS-NNNNNNNNN
title:              Short descriptive title

# ── Classification ──────────────────────────────────────────
type:               bug | feature | task | improvement | incident | research | support
priority:           critical | high | medium | low
severity:           blocker | major | minor | cosmetic | enhancement
status:             open | in_progress | resolved | closed | reopened

# ── Timestamps ──────────────────────────────────────────────
created:            YYYY-MM-DD HH:MM
updated:            YYYY-MM-DD HH:MM
resolved:           YYYY-MM-DD HH:MM     # when a solution was identified
closed:             YYYY-MM-DD HH:MM     # when the ticket was officially closed

# ── Ownership ───────────────────────────────────────────────
reporter:           Who opened this (name / system / github-user)
assignee:           Who is working on it

# ── Context ─────────────────────────────────────────────────
component:          Which part of the system (e.g. dashboard, lora-tester, character-gen)
environment:        Any relevant environment details
labels:
  - label-one
  - label-two
---
```

### Body Sections

```
## Description

Full detailed explanation of the issue or request.
What is this ticket about? Why does it matter?

## Steps to Reproduce

1. Step one
2. Step two
3. ...

## Expected Behavior

What *should* happen.

## Actual Behavior

What *actually* happens (if different from expected).

## Root Cause Analysis

What caused the problem at a fundamental level.
Include debugging findings, logs, evidence.

## Resolution

How the issue was fixed or the task completed.
Technical details, approach taken, tradeoffs considered.

**Commit:** `abc1234`  
**Repo:** https://github.com/Mystikvoyd/MystikStudio/commit/abc1234

## Workaround

If a temporary workaround exists while the ticket is open, document it here.

## Files Affected

- `path/to/file.ext` — what changed and why

## Related Tickets

- `relates_to`: MVS-NNNNNNNNN
- `blocks`:     MVS-NNNNNNNNN
- `blocked_by`: MVS-NNNNNNNNN
- `duplicates`: MVS-NNNNNNNNN
- `duplicated_by`: MVS-NNNNNNNNN
- `continues`:  MVS-NNNNNNNNN    (this ticket picks up a closed ticket's issue)
- `continued_in`: MVS-NNNNNNNNN  (this ticket's issue was continued in a new ticket)

## Notes / Comments

Any additional information, discussion, decisions, or external references.
Add a `---[YYYY-MM-DD]---` separator for chronological updates.
```
---

## Lifecycle

```
OPEN ──→ IN PROGRESS ──→ RESOLVED ──→ CLOSED
  ↑                          │
  └────── REOPENED ←─────────┘
```

| Status | Meaning |
|--------|---------|
| `open` | Ticket created, not yet being worked |
| `in_progress` | Work is actively happening |
| `resolved` | Fix/implementation complete, awaiting verification |
| `closed` | Verified and closed |
| `reopened` | Issue resurfaced after being closed |

## Continuation Chain

When an issue reoccurs or a fix needs another iteration:

1. **Close** the current ticket: set `status: closed`, fill `closed` date,
   add `continued_in: MVS-NNNNNNNNN` to frontmatter, and append to `Related Tickets`
2. **Create** the new ticket with the **next sequential number**
3. In the new ticket's frontmatter, add `continues: MVS-NNNNNNNNN` and
   duplicate the relevant context from the original
4. The chain is: `MVS-000000001 → MVS-000000005 → MVS-000000012`

## Ticket Number Allocation

Scan the `tickets/` directory for the highest existing number. Increment by one.
No centralized registry needed — filenames are the source of truth.

Numbers are **never reused**. Once `MVS-000000042` exists, it exists forever,
even if the ticket is closed or deleted.
