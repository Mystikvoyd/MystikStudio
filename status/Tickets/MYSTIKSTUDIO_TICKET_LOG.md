# MystikStudio Ticket Log

Repo: `Mystikvoyd/MystikStudio`
Purpose: Track MystikStudio work tickets, validation reports, and report bundle naming so sessions do not lose numbering.

## Ticket ID Format

Use:

`MSTK-0001`

Increment by 1 for each new MystikStudio work ticket.

Do not reuse ticket numbers.

## Report Bundle Convention

Each Leonardo/OpenCode task that creates a report should produce a zip bundle in:

`C:\Users\Michael\Documents\Leonardo Prompts\Reports`

Bundle name format:

`MSTK-0001_<short-task-name>_ReportBundle.zip`

Each bundle should include:

1. `Leo Reports.txt`
2. Any screenshots created for the task
3. Any diagnostic JSON payloads created for the task
4. Any command output text files created for the task
5. Any validation logs created for the task

The report itself must include a final section:

```text
Files to upload back to ChatGPT:
1.
2.
3.
```

If the zip bundle is created, the first upload item should be the zip bundle.

## Tickets

| Ticket | Status | Task | Report Bundle | Notes |
|---|---|---|---|---|
| MSTK-0001 | Assigned | C-Forge runtime validation with screenshots | `C:\Users\Michael\Documents\Leonardo Prompts\Reports\MSTK-0001_C-Forge_Runtime_Validation_ReportBundle.zip` | Validate running C-Forge UI with screenshots. No commit. |

## Next Ticket Number

`MSTK-0002`
