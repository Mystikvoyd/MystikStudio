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

## Per-Type Numbering Rule

The numeric sequence after the system prefix and type code increments independently inside each ticket type.

- B tickets count only B tickets.
- T tickets count only T tickets.
- M tickets count only M tickets.
- A new T ticket does not increase the B counter.
- A new B ticket does not increase the T counter.
- A new M ticket does not increase B or T.

The registry tracks the next number for each type independently.

Examples of valid independent sequences:

```text
MSTK-B-000000001-0000
MSTK-B-000000002-0000
MSTK-B-000000003-0000

MSTK-T-000000001-0000
MSTK-T-000000002-0000
MSTK-T-000000003-0000
MSTK-T-000000004-0000

MSTK-M-000000001-0000
MSTK-M-000000002-0000
```

Do not renumber existing tickets unless the current ticket standard explicitly requires a migration. Existing tickets keep their current IDs. This rule applies going forward.

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
Needs Redo
Partially Validated
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

The ZIP filename must be the exact ticket number:

```text
[TICKET-NUMBER].zip
```

Example:

```text
MSTK-B-000000003-0000.zip
```

Every ticket or child ticket worked by an agent must produce a zip package in the reports folder.

The ZIP must include:
1. Every reviewed source or script file the reviewer needs to inspect.
2. The current Leo Reports.txt file.
3. Any ticket or handoff file changed during the work.
4. Any validation output file if one was created.

The ZIP must exclude:
1. Executables such as Forge.exe, Lab.exe, and Fusion.exe.
2. bin and obj folders.
3. Model files.
4. Config files.
5. Generated build output.
6. Unrelated files.

Do not commit report ZIPs unless explicitly approved.

Every final agent report must include:
- Ticket: [exact ticket number]
- Stub: [stub or child ticket number if applicable]
- Status: [PASS, FAIL, BLOCKED, NEEDS REVIEW, or PACKAGED]
- Zip created: path to zip
- Zip contents verified: [list exact files inside the zip]
- Upload back to ChatGPT: [list exact files to upload]

If work continues under a parent ticket and no child ticket exists, use the parent ticket number for the zip.
If a child ticket exists, use the child ticket number for the zip and include the parent ticket number inside Leo Reports.txt.

## Visual Evidence Rules

Use these rules for tickets that depend on screenshots, UI layout, rendered output, image output, video output, or any other visual evidence.

- Do not claim visual PASS from file existence alone.
- Do not claim visual PASS from source inspection alone.
- Do not claim screenshot PASS unless the expected application window or output is visibly present in the screenshot.
- If the agent cannot inspect image contents directly, the report must say `VISUAL REVIEW REQUIRED`.
- If another reviewer or user provides the visual judgment, record `Screenshot source` and `Visual reviewer` in the report.
- Dropdown validation requires the dropdown list to be visibly open or the selected value to prove population. A closed dropdown showing `None` does not prove population.
- Full desktop screenshots are acceptable only when the target window is clearly visible and not obstructed.
- For multi-monitor systems, launch or move the app to the primary display before capturing evidence.
- Validation items must be marked only as PASS, FAIL, or NOT VERIFIED.
- `Assumed PASS` is not allowed.

## Canonical Ticket Template Rule

The ticket template in `TICKET_TEMPLATE.md` is part of the active project ticket rules.
The template is the **required format** for ongoing tickets.
The template is not only an example.
If `TICKET_TEMPLATE.md` changes then this standard must be reviewed and updated so the rules stay aligned.
All new ongoing tickets must follow `TICKET_TEMPLATE.md` unless a ticket has a documented exception.

## Required Ticket Template (MystikStudio Project)

This template is the canonical format for all MystikStudio ongoing tickets.
Every ticket should follow this structure unless a documented exception applies.

```
Ticket:             MSTK-[TYPE]-[TYPE-SEQUENCE]-[CHILD-SEQUENCE]
Title:              [short title]
Project:            MystikVoyd Studios
Repo:               Mystikvoyd/MystikStudio
Branch:             master
Local repo:         H:\MystikStudio
System:             MSTK
Type:               [B, T, M, F, R, or other project approved type]
Parent:             [parent ticket ID or N/A]
Child:              [child ticket ID or N/A]
Status:             [Open, Active, Blocked, Build Blocked, Needs Review, Needs Visual Review, Needs Validation, Packaged, Packaged - Needs Commit Approval, Committed, Closed, Reopened]
Owner:              [Aegis, Leo, Human, or assigned worker]
Created:            [YYYY-MM-DD]
Updated:            [YYYY-MM-DD]
Summary:            [short plain language summary]
Purpose:            [why the ticket exists]
Scope:              Files or areas that may be changed:
                    1. [file or folder]
Files not to change: 1. [file or folder]
Requirements:       1. [requirement]
Acceptance Criteria: 1. [measurable pass condition]
Validation Commands: 1. [command]
Expected Output:    [expected result]
Known Risks:        1. [risk]
Rollback Notes:     [how to undo safely if needed]
Report Package:     C:\Users\Michael\Documents\Leonardo Prompts\Reports\[TICKET-ID].zip
  Required: reviewed source files, Leo Reports.txt, changed ticket/handoff/ledger/registry files, validation output
  Exclude: executables, bin, obj, model files, config files (unless required), build output, unrelated files
Final Report:       Begin with Ticket/Stub/Status lines. Include commands run, files changed, build/launch/validation results, git status, zip path, zip contents, upload files.
```

### Per-Type Numbering Reminder

```
Ticket numbers use per-type independent sequences.
Format: MSTK-[TYPE]-[TYPE-SEQUENCE]-[CHILD-SEQUENCE]
B tickets count only B tickets.
T tickets count only T tickets.
M tickets count only M tickets.
F tickets count only F tickets.
R tickets count only R tickets.
A new T ticket does not increase the B counter.
A new B ticket does not increase the T counter.
A new M ticket does not increase B or T.
The final four digit section is for child tickets or stubs under the parent ticket.
```

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
- The ticket template is part of the active project rules. See `TICKET_TEMPLATE.md` and the Required Ticket Template section above.

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
