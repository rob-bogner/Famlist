// MARK: - Identity & List Models
//
// Privacy-first user, pairing, and list domain models (no PII).
// Swift 5.9+, iOS 17+

import Foundation

// MARK: - PublicUserId
/// Human-readable, non-PII public identifier.
struct PublicUserId: Hashable, Codable, Sendable, CustomStringConvertible {
    let value: String
    init(_ value: String) { self.value = value }
    var description: String { value }
}

// MARK: - UserProfile
struct UserProfile: Codable, Sendable {
    let id: String
    let createdAt: Date
    var status: UserStatus
}

enum UserStatus: String, Codable, Sendable { case active, disabled }

// MARK: - Grocery Domain
struct GroceryList: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let owner: PublicUserId
    var name: String
    var items: [GroceryItem]
    var sharedWith: Set<PublicUserId>
    init(id: String = UUID().uuidString, owner: PublicUserId, name: String, items: [GroceryItem] = [], sharedWith: Set<PublicUserId> = []) {
        self.id = id
        self.owner = owner
        self.name = name
        self.items = items
        self.sharedWith = sharedWith
    }
}

struct GroceryItem: Codable, Identifiable, Sendable, Hashable {
    let id: String
    var title: String
    var qty: Double
    var unit: String
    var checked: Bool
    init(id: String = UUID().uuidString, title: String, qty: Double = 1, unit: String = "", checked: Bool = false) {
        self.id = id
        self.title = title
        self.qty = qty
        self.unit = unit
        self.checked = checked
    }
}

// MARK: - Pairing
struct PairingRequest: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let from: PublicUserId
    let toCode: String
    var status: PairingStatus
    let createdAt: Date
}

enum PairingStatus: String, Codable, Sendable { case pending, approved, denied, expired }
