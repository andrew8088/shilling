---
status: ready
created: 2026-03-04
---
Context: legacy transfers carry explicit pair links and lifecycle status (`pending`, `confirmed`, `rejected`) that are currently lost.

Acceptance criteria:
- add a first-class transfer link model that references paired transactions (or entries) deterministically
- persist transfer lifecycle status and transition history needed for reconciliation
- expose import mapping hooks so legacy transfer rows can be imported without collapsing lifecycle semantics
