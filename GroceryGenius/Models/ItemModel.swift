/*
 ItemModel.swift

 GroceryGenius
 Created on: 27.11.2023
 Last updated on: 26.04.2025

 ------------------------------------------------------------------------
 📄 File Overview:

 This file defines the data model for a single shopping list item.
 It includes all attributes an item needs such as name, quantity, measurement unit, price, and check status.

 🛠 Includes:
 - Definition of the `ItemModel` structure
 - Initialization with default values
 - Support for SwiftUI (Identifiable) and data persistence (Codable)

 🔰 Notes for Beginners:
 - `Identifiable` allows SwiftUI lists to uniquely recognize each item.
 - `Codable` allows easy saving and loading of the model to JSON or databases.
 - The initializer provides default values for convenience.
 ------------------------------------------------------------------------
*/

import Foundation // Imports Foundation framework, needed for Codable and UUID functionality

/// Represents a single item in the shopping list.
/// Conforms to `Identifiable`, `Hashable`, and `Codable` for UI rendering, set operations, and persistence.
struct ItemModel: Identifiable, Hashable, Codable {
    
    // MARK: - Properties
    
    /// Unique identifier for the item.
    let id: String
    
    /// Emoji or symbol representing the item visually (e.g., 🥛 for milk).
    var image: String
    
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

    // MARK: - Initializer

    /// Initializes a new `ItemModel` instance.
    ///
    /// - Parameters:
    ///   - id: Unique identifier, defaults to a new random UUID.
    ///   - image: Symbol or emoji for the item, defaults to an empty string.
    ///   - imageData: Optional Base64-encoded image data, defaults to nil.
    ///   - name: Name of the item, defaults to an empty string.
    ///   - units: Number of units, defaults to 1.
    ///   - measure: Measurement unit, defaults to an empty string.
    ///   - price: Price per unit, defaults to 0.0.
    ///   - isChecked: Checkmark status (true if item is purchased), defaults to false.
    init(
        id: String = UUID().uuidString, // Generates a unique ID if none provided
        image: String = "", // Default image is an empty string
        imageData: String? = nil, // Default image data is nil
        name: String = "", // Default name is an empty string
        units: Int = 1, // Default to 1 unit
        measure: String = "", // Default measurement is empty
        price: Double = 0.0, // Default price is 0.0
        isChecked: Bool = false // Default to unchecked
    ) {
        self.id = id // Assigns the unique identifier
        self.image = image // Assigns the image or emoji
        self.imageData = imageData // Assigns the optional Base64 image data
        self.name = name // Assigns the item's name
        self.units = units // Assigns the quantity of the item
        self.measure = measure // Assigns the measurement unit
        self.price = price // Assigns the price per unit
        self.isChecked = isChecked // Assigns the checked status
    }
}
