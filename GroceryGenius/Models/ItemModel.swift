/*
 ItemModel.swift

 GroceryGenius
 Created on: 27.11.2023
 Last updated on: 26.04.2025

 ------------------------------------------------------------------------
 📄 File Overview:

 This file defines the data model for a single shopping list item.
 It now exclusively uses actual photos instead of emoji or symbol placeholders.
 It includes a new optional category field to classify products.
 All other attributes such as name, quantity, measurement unit, price, and check status remain.
 The model is now extended with optional fields for the exact product designation (`productDescription`) and brand/manufacturer (`brand`).

 🛠 Includes:
 - Definition of the `ItemModel` structure without the `image` field
 - Addition of an optional `category` field for product classification
 - Initialization with updated parameters and default values
 - Addition of optional `brand` and `productDescription` for detailed product info
 - Support for SwiftUI (Identifiable) and data persistence (Codable)

 🔰 Notes for Beginners:
 - `Identifiable` allows SwiftUI lists to uniquely recognize each item.
 - `Codable` allows easy saving and loading of the model to JSON or databases.
 - The initializer provides default values for convenience.
 - The removal of the `image` string field reflects a shift to using real photos only.
 - The new `category` field helps organize and filter shopping items by type.
 - The new `brand` and `productDescription` fields allow for more detailed product information, such as manufacturer and exact product designation.
 ------------------------------------------------------------------------
*/

import Foundation

/// Represents a single item in the shopping list.
/// Conforms to `Identifiable`, `Hashable`, and `Codable` for UI rendering, set operations, and persistence.
struct ItemModel: Identifiable, Hashable, Codable {
    
    // MARK: - Properties
    
    /// Unique identifier for the item.
    let id: String

    /// Owner public id for scoping (redundant to path but useful for rules/audit)
    var ownerPublicId: String?
    
    /// Base64-encoded image data representing a captured or selected photo.
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

    /// Parent grocery list identifier. Defaults to "default" for backwards compatibility.
    var listId: String

    // MARK: - Initializer

    /// Initializes a new `ItemModel` instance.
    ///
    /// - Parameters:
    ///   - id: Unique identifier, defaults to a new random UUID.
    ///   - ownerPublicId: Optional owner public id for scoping, defaults to nil.
    ///   - imageData: Optional Base64-encoded image data, defaults to nil.
    ///   - name: Name of the item, defaults to an empty string.
    ///   - units: Number of units, defaults to 1.
    ///   - measure: Measurement unit, defaults to an empty string.
    ///   - price: Price per unit, defaults to 0.0.
    ///   - isChecked: Checkmark status (true if item is purchased), defaults to false.
    ///   - category: Optional category of the product, defaults to nil.
    ///   - productDescription: Exact product designation (e.g., "Organic Whole Milk 3.5%"), defaults to nil.
    ///   - brand: Brand or manufacturer of the product (e.g., "Weihenstephan"), defaults to nil.
    ///   - listId: Parent grocery list identifier, defaults to "default" to preserve existing behavior.
    init(
        id: String = UUID().uuidString, // Generates a unique ID if none provided
        ownerPublicId: String? = nil,
        imageData: String? = nil, // Default image data is nil
        name: String = "", // Default name is an empty string
        units: Int = 1, // Default to 1 unit
        measure: String = "", // Default measurement is empty
        price: Double = 0.0, // Default price is 0.0
        isChecked: Bool = false, // Default to unchecked
        category: String? = nil, // Default category is nil (optional)
        productDescription: String? = nil, // Default product description is nil
        brand: String? = nil, // Default brand is nil
        listId: String = "default" // Default list id
    ) {
        self.id = id // Assigns the unique identifier
        self.ownerPublicId = ownerPublicId
        self.imageData = imageData // Assigns the optional Base64 image data
        self.name = name // Assigns the item's name
        self.units = units // Assigns the quantity of the item
        self.measure = measure // Assigns the measurement unit
        self.price = price // Assigns the price per unit
        self.isChecked = isChecked // Assigns the checked status
        self.category = category // Assigns the optional product category
        self.productDescription = productDescription // Assigns the exact product designation
        self.brand = brand // Assigns the brand or manufacturer
        self.listId = listId // Assigns the parent grocery list id
    }

    // MARK: - Codable (custom Decodable for backward compatibility)
    private enum CodingKeys: String, CodingKey {
        case id, ownerPublicId, imageData, name, units, measure, price, isChecked, category, productDescription, brand, listId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.ownerPublicId = try container.decodeIfPresent(String.self, forKey: .ownerPublicId)
        self.imageData = try container.decodeIfPresent(String.self, forKey: .imageData)
        self.name = try container.decode(String.self, forKey: .name)
        self.units = try container.decode(Int.self, forKey: .units)
        self.measure = try container.decode(String.self, forKey: .measure)
        self.price = try container.decode(Double.self, forKey: .price)
        self.isChecked = try container.decode(Bool.self, forKey: .isChecked)
        self.category = try container.decodeIfPresent(String.self, forKey: .category)
        self.productDescription = try container.decodeIfPresent(String.self, forKey: .productDescription)
        self.brand = try container.decodeIfPresent(String.self, forKey: .brand)
        self.listId = try container.decodeIfPresent(String.self, forKey: .listId) ?? "default"
    }
}
