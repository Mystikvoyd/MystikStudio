# Tickets Workflow

## Ticket File Format

Each ticket is a single `.md` file named:

```
TICKET-NNN_short-description.md
```

### Required Fields

```yaml
---
title: Short title
status: open | closed
opened: YYYY-MM-DD
closed: YYYY-MM-DD       # only when status=closed
continued_in: TICKET-NNN # only when status=closed and reopened later
continues: TICKET-XXX    # only when this ticket continues a closed one
type: bug | feature | task | improvement
priority: low | medium | high | critical
---
```

### Body

```markdown
## Problem
What's wrong / what's needed / why

## Solution
How it was fixed / implemented (only when closed)

## Files Affected
- path/to/file.ext — what changed

## Notes
Any additional context
```

## Lifecycle Rules

1. **Open** → create file with `status: open`, fill in problem/context
2. **Work** → reference the ticket in commits (`refs TICKET-005`)
3. **Close** → fill `closed` date and `Solution` section, set `status: closed`
4. **Reopen / Continue** → close old ticket with `continued_in: TICKET-NNN`,
   create new sequential ticket number with `continues: TICKET-XXX`
5. **Never reuse a number** — once `TICKET-042` exists, it's taken forever

## Number Allocation

Just check what the highest number in the directory is and increment by one.
No centralized registry needed — filenames are the registry.
