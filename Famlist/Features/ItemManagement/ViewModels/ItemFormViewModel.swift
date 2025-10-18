/*
 ItemFormViewModel.swift

 GroceryGenius
 Created on: 18.10.2025
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Shared ViewModel for AddItemView and EditItemView handling form state, validation, and image management.

 🛠 Includes:
 - Published form fields (name, units, measure, price, brand, etc.)
 - Validation state (@Published error messages)
 - Validation logic (field-level and form-level)
 - Image handling (UIImage ↔ Base64 conversion)

 🔰 Notes for Beginners:
 - This ViewModel eliminates duplication between Add and Edit views
 - Validation happens on field change via .onChange modifiers
 - ObservableObject pattern allows SwiftUI to react to state changes

 📝 Last Change:
 - Initial creation to centralize form logic from AddItemView and EditItemView
 ------------------------------------------------------------------------
 */

import SwiftUI // For ObservableObject and UIImage

/// Shared ViewModel managing form state and validation for item creation and editing
@MainActor
final class ItemFormViewModel: ObservableObject {
    
    // MARK: - Form Fields
    
    @Published var name: String = ""
    @Published var units: String = "1"
    @Published var measure: String = ""
    @Published var price: String = "0.0"
    @Published var brand: String = ""
    @Published var productDescription: String = ""
    @Published var category: String = ""
    @Published var isChecked: Bool = false
    @Published var selectedImage: UIImage? = nil
    
    // MARK: - Validation State
    
    @Published var nameError: String? = nil
    @Published var unitsError: String? = nil
    @Published var priceError: String? = nil
    
    // MARK: - Computed Properties
    
    /// Form is valid when all required fields pass validation
    var isValid: Bool {
        nameError == nil && 
        unitsError == nil && 
        priceError == nil && 
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Initialization
    
    /// Initialize with default values (for Add mode)
    init() {}
    
    /// Initialize with existing item (for Edit mode)
    init(item: ItemModel) {
        self.name = item.name
        self.units = String(item.units)
        self.measure = item.measure
        self.price = String(item.price)
        self.brand = item.brand ?? ""
        self.productDescription = item.productDescription ?? ""
        self.category = item.category ?? ""
        self.isChecked = item.isChecked
        
        // Load image from base64 if available
        if let img = ImageCache.shared.image(fromBase64: item.imageData) {
            self.selectedImage = img
        }
    }
    
    // MARK: - Validation Methods
    
    /// Validates all form fields at once
    func validateAll() {
        validateName()
        validateUnits()
        validatePrice()
    }
    
    /// Validates a specific field (called on .onChange)
    func validateField(_ field: FormField) {
        switch field {
        case .name: validateName()
        case .units: validateUnits()
        case .price: validatePrice()
        }
    }
    
    private func validateName() {
        nameError = ItemInputValidator.validateName(name)
    }
    
    private func validateUnits() {
        unitsError = ItemInputValidator.validateUnits(units)
    }
    
    private func validatePrice() {
        priceError = ItemInputValidator.validatePrice(price)
    }
    
    // MARK: - Data Conversion
    
    /// Converts form data to ItemModel for persistence
    /// - Parameter existingId: Optional ID for updates, generates new UUID for creates
    func toItemModel(existingId: String? = nil) -> ItemModel {
        let sanitizedName = ItemInputValidator.sanitizedName(name)
        let imageBase64 = selectedImage?.toBase64()
        
        return ItemModel(
            id: existingId ?? UUID().uuidString,
            imageData: imageBase64,
            name: sanitizedName,
            units: Int(units) ?? 1,
            measure: measure,
            price: Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0.0,
            isChecked: isChecked,
            category: category.isEmpty ? nil : category,
            productDescription: productDescription.isEmpty ? nil : productDescription,
            brand: brand.isEmpty ? nil : brand
        )
    }
    
    // MARK: - Helper Types
    
    enum FormField {
        case name, units, price
    }
}

// MARK: - Preview Helpers

extension ItemFormViewModel {
    /// Creates a pre-filled ViewModel for SwiftUI previews
    static var preview: ItemFormViewModel {
        let vm = ItemFormViewModel()
        vm.name = "Preview Item"
        vm.units = "2"
        vm.measure = "kg"
        vm.price = "5.99"
        return vm
    }
}
