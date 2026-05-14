# MystikStudio Ticket Standard

## System Code
MSTK

## Ticket Format
`MSTK-T-{parent_number:09}-{stub_number:04}`

Examples:
- Parent ticket: `MSTK-T-000000001-0000`
- First stub under that parent: `MSTK-T-000000001-0001`
- Second stub: `MSTK-T-000000001-0002`

## Ticket Files
- `status/Tickets/systems/{system_code}/MSTK_TICKET_REGISTRY.json` — Registry tracking next numbers
- `status/Tickets/systems/{system_code}/MSTK_TICKET_LEDGER.md` — Ledger of all issued tickets
- `status/Tickets/systems/{system_code}/tickets/MSTK-T-{ticket_id}_{slug}.md` — Individual ticket files

## Registry Fields
- `system_code`: Short system identifier
- `system_name`: Full system name
- `ticket_format`: Format string
- `next_parent_number`: Next parent ticket number
- `last_issued_ticket`: Last ticket ID issued
- `ticket_count`: Total parent tickets
- `stub_count`: Total stubs across all tickets
- `updated_at`: ISO date of last update
