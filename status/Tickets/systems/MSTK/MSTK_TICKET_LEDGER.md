# MSTK Ticket Ledger

MystikStudio ticket ledger using the universal ticket format:

```text
<SYS4>-<TYPE>-<PARENT_NUMBER>-<STUB_NUMBER>
```

Current system code: `MSTK`

| Ticket ID | Title | Type | Status | Owner | Created | Updated | Notes |
|----------|-------|------|--------|-------|---------|---------|-------|
| MSTK-T-000000001-0000 | Implement MystikStudio ticket system standard | T | Committed | Leonardo | 2026-05-14 | 2026-05-14 | Issued before the universal SYS4 standard was finalized. Kept as issued. |
| MSTK-T-000000002-0000 | C-Forge runtime screenshot validation | T | Blocked | Leonardo | 2026-05-14 | 2026-05-14 | Main UI visible. Dropdown population and generation blocked by MSTK-B-000000003-0000. |
| MSTK-T-000000002-0001 | C-Forge validation evidence redo | A | Closed | Leonardo | 2026-05-14 | 2026-05-14 | Redo ZIP accepted. Evidence records dropdown population as NOT VERIFIED without assumptions. |
| MSTK-T-000000002-0002 | C-Forge dropdown and generation validation | A | Blocked | Leonardo | 2026-05-14 | 2026-05-14 | User screenshot shows Forge visible and ComfyUI online, but checkpoint is None and dropdown population is not proven. Blocked by MSTK-B-000000003-0000. |
| MSTK-B-000000003-0000 | C-Forge model population and window position | B | Open | Leonardo | 2026-05-14 | 2026-05-14 | Diagnose checkpoint dropdown showing None and add primary-display or last-valid-position startup behavior. |

### MSTK-M-000000004-0000
- Title: Add standing report packaging rule to handoff docs
- Type: Maintenance
- Status: Committed
- Created: 2026-05-14
- File: tickets/MSTK-M-000000004-0000_add-standing-packaging-rule.md

### MSTK-M-000000005-0000
- Title: Update ticket numbering to per-type independent sequences
- Type: Maintenance
- Status: Packaged - Needs Commit Approval
- Created: 2026-05-14
- File: tickets/MSTK-M-000000005-0000_update-per-type-numbering.md


### MSTK-M-000000006-0000
- Title: Update ticket rules — template is canonical
- Type: Maintenance
- Status: Committed - 3aa4bbd
- Created: 2026-05-14
- File: tickets/MSTK-M-000000006-0000_update-ticket-rules-template-canon.md

### MSTK-M-000000006-0001
- Title: Status hygiene after template canon commit
- Type: Maintenance (child)
- Status: Packaged - Needs Commit Approval
- Parent: MSTK-M-000000006-0000
- Created: 2026-05-14
- File: tickets/MSTK-M-000000006-0001_status-hygiene-after-template-canon-commit.md

### MSTK-F-000000001-0000
- Title: Lab and Forge fixed seed UI freeze repair
- Type: Bug (F type)
- Status: Packaged for Review
- Created: 2026-05-14
- File: tickets/MSTK-F-000000001-0000_lab-forge-fixed-seed-ui-freeze.md

### MSTK-F-000000001-0001
- Title: Lab and Forge completion detection and settings persistence
- Type: Bug (F type child)
- Status: Packaged for Review
- Parent: MSTK-F-000000001-0000
- Created: 2026-05-14
- File: tickets/MSTK-F-000000001-0001_lab-forge-completion-detection-and-settings-persistence.md

### MSTK-F-000000001-0002
- Title: Config save/load and workflow image reference repair
- Type: Bug (F type child)
- Status: Packaged for Review
- Parent: MSTK-F-000000001-0000
- Created: 2026-05-14
- File: tickets/MSTK-F-000000001-0002_config-save-load-and-workflow-image-reference-repair.md

### MSTK-F-000000001-0003
- Title: Config load default config and workflow image state
- Type: Bug (F type child)
- Status: Packaged for Review
- Parent: MSTK-F-000000001-0000
- Created: 2026-05-14
- File: tickets/MSTK-F-000000001-0003_config-load-default-config-and-workflow-image-state.md

### MSTK-F-000000001-0004
- Title: Restore icon source assets
- Type: Bug (F type child)
- Status: Committed and Pushed
- Parent: MSTK-F-000000001-0000
- Created: 2026-05-14
- File: tickets/MSTK-F-000000001-0004_restore-icons-folder-source-assets.md
