import Foundation

/// Represents a single item in the shopping list.
struct ItemModel: Identifiable, Hashable, Codable {
    /// Unique identifier for the item.
    let id: String
    
    /// Emoji or symbol representing the item.
    var image: String
    
    /// Name of the item (e.g., "Milk", "Bread").
    var name: String
    
    /// Number of units for the item.
    var units: Int
    
    /// Measurement unit associated with the item (e.g., "liters", "packs").
    var measure: String
    
    /// Price per unit for the item.
    var price: Double
    
    /// Indicates whether the item has been checked off the list.
    var isChecked: Bool

    /// Initializes a new `ItemModel` instance.
    /// - Parameters:
    ///   - id: Unique identifier, defaults to a new UUID.
    ///   - image: Symbol or emoji for the item, defaults to an empty string.
    ///   - name: Name of the item, defaults to an empty string.
    ///   - units: Number of units, defaults to 1.
    ///   - measure: Measurement unit, defaults to an empty string.
    ///   - price: Price per unit, defaults to 0.0.
    ///   - isChecked: Checkmark status, defaults to false.
    init(
        id: String = UUID().uuidString,
        image: String = "",
        name: String = "",
        units: Int = 1,
        measure: String = "",
        price: Double = 0.0,
        isChecked: Bool = false
    ) {
        self.id = id
        self.image = image
        self.name = name
        self.units = units
        self.measure = measure
        self.price = price
        self.isChecked = isChecked
    }
}
