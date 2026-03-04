---
status: complete
created: 2026-03-03
completed: 2026-03-03
---

# Harden Import Duplicate Detection

Context: import duplicate detection is coarse and uses only a pre-import transaction snapshot.

Acceptance criteria:
- dedupe logic uses a stable transaction fingerprint that includes direction/sign semantics
- duplicates within the same CSV batch are detected and skipped
- legitimate same-day/same-payee transactions with distinct semantics are not dropped
- add regression tests in `ShillingCore/Tests/ShillingCoreTests/ImportServiceTests.swift`
