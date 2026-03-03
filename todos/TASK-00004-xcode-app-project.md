---
status: complete
created: 2026-02-28
completed: 2026-03-02
---

# Set Up macOS SwiftUI App Project

Create the Xcode project for the macOS app with ShillingCore as a local package dependency.

## Work
- Create Xcode project "Shilling" targeting macOS 14+
- Add ShillingCore as a local Swift Package dependency
- Configure ModelContainer in the app entry point
- Create a minimal shell UI (sidebar + detail layout) to verify the setup works
- App should launch, create the SwiftData store, and display an empty state

## Acceptance Criteria
- App builds and launches from Xcode
- SwiftData store is created on disk
- ShillingCore models are accessible from the app
