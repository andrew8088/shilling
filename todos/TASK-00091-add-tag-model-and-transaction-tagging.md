---
status: ready
created: 2026-03-04
---
Context: legacy data includes user tags and transaction taggings that are currently dropped.

Acceptance criteria:
- add tag and tagging models with uniqueness and referential constraints
- support importing legacy `tags` and `taggings` without losing link fidelity
- include read/write service APIs so tags are usable beyond one-time import
