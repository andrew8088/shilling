---
status: ready
created: 2026-03-04
---
Context: legacy rules support nested condition trees (`parent_id`) and action imports that exceed current planned flat rule assumptions.

Acceptance criteria:
- extend import rule domain to represent nested/compound condition trees
- map legacy `rule_conditions` and `rule_actions` into the new structure with deterministic execution order
- document integration boundaries with `PROJ-00059` to avoid duplicated rule-engine work
