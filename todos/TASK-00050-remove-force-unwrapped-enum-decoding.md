---
status: ready
created: 2026-03-03
---

# Remove Force-Unwrapped Enum Decoding

Context: model enum decoding currently force-unwraps raw values and can crash on malformed persisted data.

Acceptance criteria:
- replace force unwraps in enum-backed model properties with safe handling
- define explicit behavior for invalid raw values (fallback or surfaced error)
- add tests that exercise invalid persisted values and verify no crash
- document migration/compatibility behavior if applicable
