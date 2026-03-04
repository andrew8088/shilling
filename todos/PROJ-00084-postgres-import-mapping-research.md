---
status: complete
created: 2026-03-04
completed: 2026-03-04
tasks:
  - TASK-00085-inventory-legacy-postgres-schema.md
  - TASK-00086-map-legacy-schema-to-shilling-model.md
  - TASK-00087-propose-import-capability-gap-tasks.md
---
Context: we need to import data from a legacy PostgreSQL budgeting app database (`maybe_2026_03_03`) into Shilling without losing fidelity.

Acceptance criteria:
- legacy schema is fully inventoried with table-level semantics and key constraints
- legacy-to-Shilling mapping is documented with explicit field-level transformations
- model/import capability gaps are identified with concrete follow-up task tickets
