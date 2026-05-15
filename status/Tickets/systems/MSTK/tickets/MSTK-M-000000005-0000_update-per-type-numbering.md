# MSTK-M-000000005-0000: Update ticket numbering to per-type independent sequences

System: MystikStudio
Type: Maintenance
Status: Packaged - Needs Commit Approval
Created: 2026-05-14
Repo: Mystikvoyd/MystikStudio
Branch: master

## Per-Type Numbering Rule

The numeric sequence after the system prefix and type code increments independently inside each ticket type.

- B tickets count only B tickets.
- T tickets count only T tickets.
- M tickets count only M tickets.
- A new T ticket does not increase the B counter.
- A new B ticket does not increase the T counter.

Format: MSTK-[TYPE]-[TYPE-SEQUENCE]-[CHILD-SEQUENCE]

The registry tracks the next sequence number for each type independently.
Schema version updated from 1.0 to 2.0 to reflect the per-type numbering change.

## Files Changed

- status/Tickets/TICKET_STANDARD.md — added Per-Type Numbering Rule section
- status/Tickets/systems/MSTK/MSTK_TICKET_REGISTRY.json — schema v2.0, added type_sequences
- status/Tickets/systems/MSTK/MSTK_TICKET_LEDGER.md — added this ticket
- status/Tickets/TICKET_TEMPLATE.md — added numbering rule section
