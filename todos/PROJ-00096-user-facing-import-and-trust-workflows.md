---
status: ready
created: 2026-03-04
tasks:
  - TASK-00060-add-import-rule-model-and-matching-engine.md
  - TASK-00061-add-import-review-queue-domain-and-state.md
  - TASK-00062-extend-import-wizard-with-rule-suggestions-and-overrides.md
  - TASK-00063-add-import-rule-tests-and-docs.md
  - TASK-00090-add-transfer-link-and-lifecycle-model.md
  - TASK-00055-add-entry-clear-and-reconcile-state.md
  - TASK-00056-build-reconciliation-service-and-diff-calculation.md
  - TASK-00057-add-account-reconciliation-ui-flow.md
  - TASK-00058-add-reconciliation-tests-and-docs.md
  - TASK-00089-add-source-metadata-envelope-for-import-fidelity.md
---
Context: prioritize user-facing import speed, transaction correctness, and trust workflows over full legacy-schema parity.

Acceptance criteria:
- import includes practical review and rule tooling that materially reduces cleanup effort
- transfer handling and reconciliation workflows improve day-to-day confidence in balances and reports
- implementation sequence avoids non-user-facing parity work until direct demand is confirmed
