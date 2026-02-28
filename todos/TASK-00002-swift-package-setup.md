---
status: ready
created: 2026-02-28
---

# Set Up ShillingCore Swift Package

Create the ShillingCore Swift Package with the correct directory structure and dependencies.

## Work
- Create `ShillingCore/Package.swift` with:
  - Library target: `ShillingCore`
  - Executable target: `ShillingCLI` (depends on ShillingCore + swift-argument-parser)
  - Test target: `ShillingCoreTests`
- Platform: macOS 14+
- Dependencies: swift-argument-parser
- Set up directory structure under `Sources/` and `Tests/`
- Verify it compiles with `swift build`

## Acceptance Criteria
- `swift build` succeeds
- `swift test` runs (even if no tests yet)
- Package structure matches architecture doc
