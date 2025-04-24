import Foundation

struct ItemModel: Identifiable, Hashable, Codable {
    let id: String
    var image: String
    var name: String
    var units: Int
    var measure: String
    var price: Double
    var isChecked: Bool

    init(id: String = UUID().uuidString, image: String = "", name: String = "", units: Int = 1, measure: String = "", price: Double = 0.0, isChecked: Bool = false) {
        self.id = id
        self.image = image
        self.name = name
        self.units = units
        self.measure = measure
        self.price = price
        self.isChecked = isChecked
    }
}
