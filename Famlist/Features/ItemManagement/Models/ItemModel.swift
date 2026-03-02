/*
 ItemModel.swift

 Famlist
 Created on: 27.11.2023
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Data model for a single shopping list item. Maps fields to Supabase/Postgres columns and supports SwiftUI (Identifiable) and persistence (Codable).

 🛠 Includes:
 - ItemModel struct with properties for image, name, units, measure, price, check state, category, description, brand, listId, owner.
 - Memberwise initializer with defaults for convenience.

 🔰 Notes for Beginners:
 - Identifiable helps SwiftUI lists track items by id.
 - Codable enables encoding/decoding from JSON used by the network/database layer.
 - listId links the item to a specific list (matches items.list_id in the DB).

 📝 Last Change:
 - Documented imageUrl/imageData migration plan and position field as technical debt.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides Codable, UUID, and core types used for the model.

/// Represents a single item in the shopping list.
/// Conforms to `Identifiable`, `Hashable`, and `Codable` for UI rendering, set operations, and persistence.
struct ItemModel: Identifiable, Hashable, Codable {
    
    // MARK: - Properties
    
    /// Unique identifier for the item.
    let id: String

    /// TODO: [Future Migration] Public or signed URL to image in Supabase Storage
    /// Current Status: NOT IMPLEMENTED - imageUrl is not used anywhere in the codebase
    /// Migration Plan: When DB size becomes an issue, migrate to:
    ///   1. Upload images to Supabase Storage
    ///   2. Store URLs here instead of Base64
    ///   3. Implement local cache (Data) for offline availability
    ///   4. Remove imageData after migration complete
    /// Trade-off: Base64 works offline but bloats DB; URLs are small but need caching
    var imageUrl: String?

    /// Base64-encoded image data for offline-first functionality
    /// Note: This approach stores images directly in the database which impacts size/performance
    /// See imageUrl documentation for planned migration path
    var imageData: String?
    
    /// Name of the item (e.g., "Milk", "Bread").
    var name: String
    
    /// Number of units for the item (e.g., 2 liters, 3 packs).
    var units: Int
    
    /// Measurement unit associated with the item (e.g., "liters", "packs").
    var measure: String
    
    /// Price per unit for the item (e.g., 1.99 EUR).
    var price: Double
    
    /// Boolean flag indicating whether the item has been checked off the list.
    var isChecked: Bool
    
    /// Category or group of the product (e.g., "Dairy", "Bakery", "Vegetables").
    var category: String?

    /// Exact product designation (e.g., "Organic Whole Milk 3.5%").
    var productDescription: String?

    /// Brand or manufacturer of the product (e.g., "Weihenstephan").
    var brand: String?

    /// Owning list UUID as String (maps to items.list_id in DB).
    var listId: String?

    /// Optional owner public id, if available (maps to items.ownerPublicId in DB).
    var ownerPublicId: String?

    /// Creation timestamp of the item.
    var createdAt: Date?

    /// Last update timestamp of the item.
    var updatedAt: Date?
    
    // MARK: - CRDT Metadata (Optional for backward compatibility)
    
    /// HLC timestamp in milliseconds for causal ordering
    var hlcTimestamp: Int64?
    
    /// HLC logical counter for same-timestamp disambiguation
    var hlcCounter: Int?
    
    /// HLC node identifier (device/user UUID)
    var hlcNodeId: String?
    
    /// Tombstone flag for CRDT deletions
    var tombstone: Bool?
    
    /// Identifier of last modifier (for conflict tracking)
    var lastModifiedBy: String?
    
    // MARK: - Sorting Logic
    
    /// Determines the sort order between two items based on creation date and ID.
    /// Used to ensure consistent sorting across list views and merge strategies.
    /// - Parameters:
    ///   - lhs: Left-hand side item.
    ///   - rhs: Right-hand side item.
    /// - Returns: True if lhs should come before rhs.
    static func compare(_ lhs: ItemModel, _ rhs: ItemModel) -> Bool {
        let leftDate = lhs.createdAt ?? Date.distantPast
        let rightDate = rhs.createdAt ?? Date.distantPast
        
        // Sort by creation date (older items first)
        // We use a threshold of 1 second to ignore tiny differences during sync
        if abs(leftDate.timeIntervalSince(rightDate)) > 1 {
            return leftDate < rightDate
        }
        
        // Fallback to ID for stable sort on identical timestamps
        return lhs.id < rhs.id
    }
    
    // MARK: - CodingKeys
    private enum CodingKeys: String, CodingKey {
        case id, imageUrl, imageData, name, units, measure, price, isChecked, category
        case productDescription, brand, listId, ownerPublicId
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case hlcTimestamp = "hlc_timestamp"
        case hlcCounter = "hlc_counter"
        case hlcNodeId = "hlc_node_id"
        case tombstone
        case lastModifiedBy = "last_modified_by"
    }
    
    // MARK: - Initializer

    /// Initializes a new `ItemModel` instance.
    ///
    /// - Parameters:
    ///   - id: Unique identifier, defaults to a new random UUID.
    ///   - imageUrl: Optional image URL (Supabase Storage), defaults to nil.
    ///   - imageData: Optional Base64-encoded image data, defaults to nil.
    ///   - name: Name of the item, defaults to an empty string.
    ///   - units: Number of units, defaults to 1.
    ///   - measure: Measurement unit, defaults to an empty string.
    ///   - price: Price per unit, defaults to 0.0.
    ///   - isChecked: Checkmark status (true if item is purchased), defaults to false.
    ///   - category: Optional category of the product, defaults to nil.
    ///   - productDescription: Exact product designation (e.g., "Organic Whole Milk 3.5%"), defaults to nil.
    ///   - brand: Brand or manufacturer of the product (e.g., "Weihenstephan"), defaults to nil.
    ///   - listId: Identifier of the containing list, defaults to nil (set by caller when known).
    ///   - ownerPublicId: Optional owner public id used for sharing features.
    ///   - createdAt: Creation timestamp, defaults to now.
    ///   - updatedAt: Last update timestamp, defaults to now.
    ///   - hlcTimestamp: HLC timestamp (optional, for CRDT)
    ///   - hlcCounter: HLC counter (optional, for CRDT)
    ///   - hlcNodeId: HLC node ID (optional, for CRDT)
    ///   - tombstone: Tombstone flag (optional, for CRDT deletions)
    ///   - lastModifiedBy: Last modifier ID (optional, for CRDT)
    init(
        id: String = UUID().uuidString, // Generates a unique ID if none provided
        imageUrl: String? = nil,
        imageData: String? = nil, // Default image data is nil
        name: String = "", // Default name is an empty string
        units: Int = 1, // Default to 1 unit
        measure: String = "", // Default measurement is empty
        price: Double = 0.0, // Default price is 0.0
        isChecked: Bool = false, // Default to unchecked
        category: String? = nil, // Default category is nil (optional)
        productDescription: String? = nil, // Default product description is nil
        brand: String? = nil, // Default brand is nil
        listId: String? = nil, // Default to nil
        ownerPublicId: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        hlcTimestamp: Int64? = nil,
        hlcCounter: Int? = nil,
        hlcNodeId: String? = nil,
        tombstone: Bool? = nil,
        lastModifiedBy: String? = nil
    ) {
        self.id = id // Assigns the unique identifier
        self.imageUrl = imageUrl
        self.imageData = imageData // Assigns the optional Base64 image data
        self.name = name // Assigns the item's name
        self.units = units // Assigns the quantity of the item
        self.measure = measure // Assigns the measurement unit
        self.price = price // Assigns the price per unit
        self.isChecked = isChecked // Assigns the checked status
        self.category = category // Assigns the optional product category
        self.productDescription = productDescription // Assigns the exact product designation
        self.brand = brand // Assigns the brand or manufacturer
        self.listId = listId
        self.ownerPublicId = ownerPublicId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.hlcTimestamp = hlcTimestamp
        self.hlcCounter = hlcCounter
        self.hlcNodeId = hlcNodeId
        self.tombstone = tombstone
        self.lastModifiedBy = lastModifiedBy
    }
}
