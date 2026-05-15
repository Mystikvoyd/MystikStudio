# MystikStudio Ticket Template

This template is the required format for ongoing MystikStudio tickets.
See TICKET_STANDARD.md > Canonical Ticket Template Rule for the full standard.

## Per-Type Numbering

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

## Required Ticket Fields

Ticket:
Title:
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

Summary:
[short plain language summary]

Purpose:
[why the ticket exists]

Scope:
Files or areas that may be changed:
1. [file or folder]

Files not to change:
1. [file or folder]

Requirements:
1. [requirement]

Acceptance Criteria:
1. [measurable pass condition]

Validation Commands:
1. [command]

Expected Output:
[expected result]

Known Risks:
1. [risk]

Rollback Notes:
[how to undo safely if needed]

## Report Package

Expected zip: C:\Users\Michael\Documents\Leonardo Prompts\Reports\[TICKET-ID].zip

Required package contents:
1. Every reviewed source or script file needed for ChatGPT inspection.
2. C:\Users\Michael\Documents\Leonardo Prompts\Leo Reports.txt
3. Changed ticket files.
4. Changed handoff files.
5. Changed ledger or registry files.
6. Validation output files if created.

Do not include:
1. Executables.
2. bin folders.
3. obj folders.
4. Model files.
5. Config files unless explicitly required.
6. Generated build output.
7. Unrelated files.

## Final Report Requirements

The final report must begin exactly:

Ticket: [TICKET-ID]
Stub: [CHILD TICKET ID or N/A]
Status: [PASS, FAIL, BLOCKED, NEEDS REVIEW, PACKAGED, PACKAGED - NEEDS COMMIT APPROVAL, COMMITTED AND PUSHED]

The final report must include:
1. Commands run.
2. Command output summary.
3. Current latest commit.
4. Files changed.
5. Build result if applicable.
6. Launch result if applicable.
7. Validation result.
8. Current git status --short.
9. Whether generated files changed but were not staged.
10. Recommended commit files.
11. Zip created.
12. Zip contents verified.
13. Exact file to upload back.

