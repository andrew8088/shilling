---
status: ready
created: 2026-03-04
---
Context: legacy `balances` contains daily account snapshots and flow decomposition that cannot be represented today.

Acceptance criteria:
- add a balance snapshot model that stores per-account daily balances with source date
- import legacy `balances` with currency and flow-component fields required for net-worth history parity
- provide query/service support for time-series reports based on snapshots
