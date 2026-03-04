---
status: ready
created: 2026-03-04
---
Context: current models only have free-text notes, so legacy source IDs and semantics cannot be preserved safely.

Acceptance criteria:
- add structured metadata storage for imported domain records (at minimum transaction-level)
- define a stable metadata contract for source system, source record IDs, import IDs, and mapping decisions
- ensure metadata survives CRUD updates and can be queried for audit/replay workflows
