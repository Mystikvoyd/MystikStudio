# .sisyphus — Persistent Context System

This directory is a **self-documenting knowledge base** embedded in the repo.
It exists so that future LLM sessions (and collaborators) can pick up exactly
where the last one left off — without needing chat history.

## File Hierarchy

```
.sisyphus/
├── README.md          ← This file — how the system works
├── CURSOR.md          ← CURRENT STATE — what's being thought about right now
├── TASKS.md           ← WORK QUEUE — ordered tasks, read BEFORE making any edits
├── plans/             ← Detailed design plans (one per task/feature)
├── worklog/           ← Diary of what was done, chronologically
└── tickets/           ← Problem/feature tickets, one per file
```

## Protocol for ALL AI agents

### 1. ENTRY — always start here

1. Read `CURSOR.md` → know what's in progress, what decisions were made
2. Read `TASKS.md` → know what to do next, in order
3. Read the latest ticket(s) in `tickets/` that are `status: open`
4. Read the most recent entry in `worklog/` to see what was just done

**Do NOT start editing until you have read all four.**

### 2. DURING WORK

- Mark tasks `in_progress` in `TASKS.md` as you start them
- If you discover something that changes the plan, update `CURSOR.md` first
- For any bug/feature that takes >5min to fix, open a ticket in `tickets/`

### 3. EXIT — always end here

Before finishing a session, update:

1. **`CURSOR.md`** — reflect new state: what's done, what's next, decisions made
2. **`TASKS.md`** — mark completed tasks `done`, add any new tasks discovered
3. **`worklog/`** — append a dated entry: what was done, files changed, why
4. **`tickets/`** — close resolved tickets, open new ones for remaining work
5. **Commit and push** all `.sisyphus/` changes

### 4. TICKET LIFECYCLE

- Tickets are numbered sequentially: `TICKET-001`, `TICKET-002`, ...
- Each ticket is a single `.md` file in `tickets/`
- Fields: `title`, `status`, `opened`, `closed`, `problem`, `solution`, `files`
- **When a ticket is closed and the same issue reoccurs or needs continuation:**
  - Close the old ticket with `continued_in: TICKET-NNN`
  - Create a NEW ticket (next sequential number) that starts with `continues: TICKET-XXX`
  - This creates a traceable chain without reusing numbers
- Never reuse a ticket number. Numbers are unique forever.
