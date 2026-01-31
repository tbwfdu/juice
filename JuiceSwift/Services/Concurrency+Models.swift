// This file adds Sendable conformance to model types used across actors.
// If these types are value types with only Sendable members, consider switching to plain `Sendable`.

import Foundation

// MARK: - Concurrency Bridges

// Allow CaskApplication to cross actor boundaries.
// Replace `@unchecked Sendable` with `Sendable` if the type is fully safe for concurrency.
extension CaskApplication: @unchecked Sendable {}

// Allow Recipe to cross actor boundaries.
extension Recipe: @unchecked Sendable {}
