# Universal Ticket ID Standard

## Purpose

This standard defines a reusable ticket ID format for any project, system, app, repo, operational area, or workstream. It allows each system to keep a separate ticket database while preserving one common structure for ticket IDs, ledgers, reports, evidence, and handoffs.

This is a system neutral standard. MystikStudio uses the `MSTK` system code, but other systems must choose their own four character system code.

## Ticket ID Format

```text
<SYS4>-<TYPE>-<PARENT_NUMBER>-<STUB_NUMBER>
```

Example:

```text
MSTK-T-000000001-0000
```

## Required Parts

### SYS4

A required four character system code.

Examples:

```text
MSTK = MystikStudio
PREV = Project Revolution
HERM = Hermes
LABS = Lab
FORG = Forge
DASH = Dashboard
NETW = Network
BOOK = Book or writing project
```

Rules:

- Must be exactly four characters.
- Use uppercase letters and numbers only.
- Must be unique inside the repo or organization.
- Do not use `MSTK` for every system.
- Each system gets its own registry and ledger.

### TYPE

A one to three character ticket type code.

Recommended starting set:

```text
T = Task or general ticket
I = Incident
P = Problem
R = Request
C = Change
B = Bug
E = Enhancement
D = Decision
K = Knowledge
A = Audit
M = Maintenance
```

Use `T` when unsure. Use a more specific type only when it clearly fits.

### PARENT_NUMBER

A nine digit parent ticket number.

Example:

```text
000000001
```

Rules:

- Parent numbers are assigned by the system registry.
- Never assign a parent number from memory or chat.
- Never reuse a parent number.
- Never renumber closed tickets.

### STUB_NUMBER

A four digit subtask number.

Rules:

- Parent tickets always use `0000`.
- Stub tickets increment from `0001`.
- Stub tickets keep the same parent number.

Examples:

```text
MSTK-T-000000001-0000  Parent ticket
MSTK-T-000000001-0001  First subtask
MSTK-T-000000001-0002  Second subtask
```

## Ticket Type Definitions

### T = Task

Use for normal planned work or when no other type clearly fits.

### I = Incident

Use when something is broken, degraded, blocked, failing, unavailable, or requires restoration of service or function.

### P = Problem

Use when investigating root cause, especially repeated incidents, unknown cause failures, recurring defects, or unstable behavior.

### R = Request

Use for standard service requests, setup requests, access requests, information requests, or user requested service actions.

### C = Change

Use for planned changes that may affect behavior, configuration, infrastructure, workflow, release state, or risk.

### B = Bug

Use for a confirmed defect in software, workflow, UI, data, documentation, or automation.

### E = Enhancement

Use for new features, improvements, polish, UX upgrades, automation additions, or capability expansion.

### D = Decision

Use when a decision needs to be tracked, approved, rejected, revisited, or preserved for later reference.

### K = Knowledge

Use for documentation, handoffs, standards, runbooks, FAQs, lessons learned, or reference material.

### A = Audit

Use for validation, review, evidence capture, compliance checks, security review, source inspection, or housekeeping review.

### M = Maintenance

Use for recurring upkeep, cleanup, dependency updates, version updates, housekeeping, or scheduled health checks.

## Required Ticket Fields

Every ticket file should include these fields when applicable:

```text
Ticket ID:
Title:
System:
Type:
Status:
Priority:
Owner:
Created:
Updated:
Parent:
Stub:
Related tickets:
Repo:
Branch:
Local path:
Summary:
Reason:
Scope:
Out of scope:
Acceptance criteria:
Validation steps:
Evidence:
Files changed:
Files not to touch:
Risks:
Rollback plan:
Current result:
Next action:
Close criteria:
```

## Status Values

```text
New
Open
Active
Blocked
Needs Review
Needs Testing
Ready to Commit
Committed
Pushed
Closed
Cancelled
Deferred
```

## Priority Values

```text
P0 = Critical, system unusable or destructive risk
P1 = High, blocking major work
P2 = Normal, planned important work
P3 = Low, cleanup or polish
P4 = Backlog, future idea
```

## Repo Structure Template

```text
status/Tickets/
  TICKET_STANDARD.md
  TICKET_TEMPLATE.md
  systems/
    <SYS4>/
      <SYS4>_TICKET_REGISTRY.json
      <SYS4>_TICKET_LEDGER.md
      tickets/
        <SYS4>-<TYPE>-000000001-0000_example-parent-ticket.md
        <SYS4>-<TYPE>-000000001-0001_example-subtask.md
      reports/
        <SYS4>-<TYPE>-000000001-0000_Report.zip
```

## Registry Template

```json
{
  "schema_version": "1.0",
  "system_code": "MSTK",
  "system_name": "MystikStudio",
  "ticket_format": "<SYS4>-<TYPE>-<PARENT_NUMBER>-<STUB_NUMBER>",
  "allowed_types": ["T", "I", "P", "R", "C", "B", "E", "D", "K", "A", "M"],
  "next_parent_number": 1,
  "last_issued_ticket": null,
  "ticket_count": 0,
  "stub_count": 0,
  "updated_at": "YYYY-MM-DD"
}
```

The registry is the numbering authority for its system. Do not issue a ticket ID unless the registry is updated in the same work packet.

## Ledger Template

```markdown
# Ticket Ledger for <SYSTEM_NAME>

| Ticket ID | Title | Type | Status | Owner | Created | Updated | Notes |
|----------|-------|------|--------|-------|---------|---------|-------|
```

## Ticket File Naming

Use lowercase descriptive names after the ticket ID.

Examples:

```text
MSTK-K-000000001-0000_ticket-system-standard.md
MSTK-A-000000002-0000_c-forge-runtime-validation.md
MSTK-B-000000003-0000_lab-seed-box-overlap.md
```

Previously issued tickets should not be renumbered only to change type. If a ticket was created as `T` before a better type was chosen, keep the original ID and classify the type in the ticket body.

## Report Package Naming

Reports should use the ticket ID first.

Example:

```text
MSTK-A-000000002-0000_C-Forge-Runtime-Validation.zip
```

Recommended local report folder:

```text
C:\Users\Michael\Documents\Leonardo Prompts\Reports
```

The ZIP should contain:

```text
Leo Reports.txt
screenshots if created
payload JSON if created
validation logs if created
ticket.txt
```

Do not commit report ZIPs unless explicitly approved.

## Rules

- The repo registry is the source of truth for ticket numbering.
- Never assign the next number from memory or chat.
- Parent tickets end in `-0000`.
- Stub tickets use the same parent number and increment the stub number.
- Do not reuse ticket IDs.
- Do not renumber closed tickets.
- Do not delete ticket files. Mark them Cancelled, Deferred, or Closed.
- Do not commit report ZIPs unless explicitly approved.
- Do not use one system code for every project.
- Use `T` when unsure. Use a more specific type only when it clearly fits.

## Suggested Type Selection

```text
Use I when something is broken right now.
Use P when the cause is unknown or recurring.
Use R when someone asks for a standard service action.
Use C when changing behavior, config, release state, workflow, infrastructure, or risk.
Use B when there is a confirmed defect.
Use E when adding or improving capability.
Use D when the important output is a decision.
Use K when the important output is documentation.
Use A when the important output is verification or evidence.
Use M when the work is upkeep or cleanup.
```
