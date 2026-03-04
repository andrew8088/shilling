---
status: ready
created: 2026-03-04
tasks:
  - TASK-00089-add-source-metadata-envelope-for-import-fidelity.md
  - TASK-00090-add-transfer-link-and-lifecycle-model.md
  - TASK-00091-add-tag-model-and-transaction-tagging.md
  - TASK-00092-add-valuation-snapshot-model-and-import.md
  - TASK-00093-add-daily-balance-snapshot-model-and-import.md
  - TASK-00094-add-import-provenance-staging-models.md
  - TASK-00095-extend-rule-model-for-legacy-nested-rule-parity.md
---
Context: legacy Postgres import mapping research found data-semantics gaps that the current Shilling schema cannot preserve.

Acceptance criteria:
- child tasks cover each identified fidelity gap with concrete implementation scope
- sequencing prioritizes transaction correctness and traceability before historical analytics layers
- overlap with existing import-rule work is explicit to avoid duplicate implementation tracks
