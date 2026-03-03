import ShillingCore

// SwiftUI.Transaction conflicts with ShillingCore.Transaction.
// Since there's also a `ShillingCore` enum in the module, we can't use `ShillingCore.Transaction`.
// Use this typealias throughout the app to refer to the domain model.
typealias Txn = ShillingCore.Transaction
