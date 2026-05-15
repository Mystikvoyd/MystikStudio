# Ticket Template

Ticket numbers use per-type independent sequences.

Format: MSTK-[TYPE]-[TYPE-SEQUENCE]-[CHILD-SEQUENCE]

Meaning:
- B tickets count only B tickets.
- T tickets count only T tickets.
- M tickets count only M tickets.
- A new T ticket does not increase the B counter.
- A new B ticket does not increase the T counter.
- A new M ticket does not increase B or T.

Examples:
- MSTK-B-000000001-0000, MSTK-B-000000002-0000, MSTK-B-000000003-0000
- MSTK-T-000000001-0000, MSTK-T-000000002-0000, MSTK-T-000000003-0000, MSTK-T-000000004-0000
- MSTK-M-000000001-0000, MSTK-M-000000002-0000

Child or stub sequence:
The final four digit section remains for child or stub numbering under the parent ticket.
Examples: MSTK-B-000000003-0000 is the parent. MSTK-B-000000003-0001 is child or stub 1.

See TICKET_STANDARD.md > Per-Type Numbering Rule for the full standard.

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

## Summary

## Reason

## Scope

## Out of Scope

## Acceptance Criteria

1.
2.
3.

## Validation Steps

1.
2.
3.

## Evidence

## Files Changed

## Files Not To Touch

## Risks

## Rollback Plan

## Current Result

## Next Action

## Close Criteria

