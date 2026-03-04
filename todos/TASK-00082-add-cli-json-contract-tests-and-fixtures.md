---
status: ready
created: 2026-03-04
---

# Add Cli Json Contract Tests And Fixtures

Context: scripting users need stable JSON contracts across releases.

Acceptance criteria:
- define canonical JSON schemas or fixtures for each CLI command family
- add tests that assert field names, types, and required keys for JSON outputs
- add regression coverage for backward-compatible evolution of JSON payloads
- fail CI on contract-breaking output changes unless explicitly versioned
