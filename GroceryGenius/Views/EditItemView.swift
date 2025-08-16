//
//  EditItemView.swift
//  GroceryGenius
//  Created: 27.11.2023
//  Last Updated: 31.05.2025
//
// ------------------------------------------------------------------------
// 📄 File Overview:
// EditItemView allows the user to edit all fields of an existing shopping item
// in a modern, card-like UI. Includes image picker, all item properties as text fields,
// and a single Save button. Layout and logic are harmonized with AddItemView.
//
// 🛠️ Features:
// - Card-style vertical stack layout for all item fields
// - Photo picker supporting camera and gallery, with preview
// - All ItemModel properties as editable fields (name, brand, productDescription, category, units, measure, price)
// - Save button at the bottom, closes on success
// - Close button at top right
// - Consistent style, dark mode support
// - Thoroughly commented for beginners
// ------------------------------------------------------------------------

import SwiftUI

/// A view for editing an existing item in the shopping list.
/// All properties can be edited, including name, brand, description, category, units, measure, price, and photo.
struct EditItemView: View {

    // MARK: - Properties
    /// Dismiss action to close the sheet
    @Environment(\.dismiss) private var dismiss

    /// The view model for the list, needed to update the item
    @EnvironmentObject var listViewModel: ListViewModel

    /// The item being edited
    let item: ItemModel

    // Editable fields, initialized from the current item's properties
    @State private var name: String = ""
    @State private var brand: String = ""
    @State private var productDescription: String = ""
    @State private var category: String = ""
    @State private var units: String = "1"
    @State private var measure: String = ""
    @State private var price: String = "0.0"
    @State private var isChecked: Bool = false

    /// Holds the currently selected photo (UIImage)
    @State private var selectedImage: UIImage? = nil

    /// Focus management for the first text field (item name)
    @FocusState private var isNameFieldFocused: Bool

    @State private var nameError: String? = nil
    @State private var unitsError: String? = nil
    @State private var priceError: String? = nil

    // MARK: - Body

    var body: some View {
        CustomModalView(title: "Edit Item", onClose: { dismiss() }) {
            VStack(spacing: DS.Spacing.l) {
                ScrollView {
                    VStack(spacing: DS.Spacing.m) {
                        PhotoField(image: $selectedImage)
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Name", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(1)
                                .focused($isNameFieldFocused)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(nameError == nil ? Color.clear : Color.red, lineWidth: 1)
                                )
                            if let nameError { Text(nameError).font(.caption2).foregroundColor(.red) }
                        }
                        TextField("Brand", text: $brand)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1)
                        TextField("Product Description", text: $productDescription)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1)
                        TextField("Category", text: $category)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1)
                        VStack(alignment: .leading, spacing: 4) {
                            QuantityMeasureRow(units: $units, measure: $measure)
                            if let unitsError { Text(unitsError).font(.caption2).foregroundColor(.red) }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            PriceField(price: $price, errorMessage: priceError)
                            if let priceError { Text(priceError).font(.caption2).foregroundColor(.red) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 25)
                }
                PrimaryButton(title: "Save") {
                    // Synchrone Validierung
                    let currentNameError = ItemInputValidator.validateName(name)
                    let currentUnitsError = ItemInputValidator.validateUnits(units)
                    let currentPriceError = ItemInputValidator.validatePrice(price)
                    nameError = currentNameError
                    unitsError = currentUnitsError
                    priceError = currentPriceError
                    guard currentNameError == nil, currentUnitsError == nil, currentPriceError == nil else { return }
                    saveChanges()
                    dismiss()
                }
                .disabled(!formValid)
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear { populateFields(); validateAll() }
            .onChange(of: name) { _ , _ in validateName() }
            .onChange(of: units) { _ , _ in validateUnits() }
            .onChange(of: price) { _ , _ in validatePrice() }
            .presentationDetents([.height(570)])
        }
    }

    // MARK: - Helper Functions

    private var formValid: Bool { nameError == nil && unitsError == nil && priceError == nil }
    private func validateName() { nameError = ItemInputValidator.validateName(name) }
    private func validateUnits() { unitsError = ItemInputValidator.validateUnits(units) }
    private func validatePrice() { priceError = ItemInputValidator.validatePrice(price) }
    private func validateAll() { validateName(); validateUnits(); validatePrice() }

    /// Initializes the editable fields with the current item's properties
    private func populateFields() {
        name = item.name
        brand = item.brand ?? ""
        productDescription = item.productDescription ?? ""
        category = item.category ?? ""
        units = String(item.units)
        measure = item.measure
        price = String(item.price)
        isChecked = item.isChecked

        // Load image from base64 string if available
        if let img = ImageCache.shared.image(fromBase64: item.imageData) {
            selectedImage = img
        }
    }

    /// Save all changes to the item and update the model
    private func saveChanges() {
        let sanitizedName = ItemInputValidator.sanitizedName(name)
        // Convert selected image to base64 string, if available
        let imageBase64 = selectedImage?.jpegData(compressionQuality: 0.8)?.base64EncodedString()
        // Create the updated ItemModel
        let updatedItem = ItemModel(
            id: item.id,
            imageData: imageBase64,
            name: sanitizedName,
            units: Int(units) ?? 1,
            measure: measure,
            price: Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0.0,
            isChecked: isChecked,
            category: category,
            productDescription: productDescription,
            brand: brand
        )
        listViewModel.updateItem(updatedItem) // Update in the view model (and Firestore)
    }
}

#Preview {
    /// Preview for EditItemView using the new layout and logic.
    EditItemView(item: ItemModel(
        id: UUID().uuidString,
        imageData: nil,
        name: "Milch",
        units: 1,
        measure: "L",
        price: 1.99,
        isChecked: false,
        category: "Milchprodukte",
        productDescription: "Haltbare Milch 3,5%",
        brand: "Demeter"
    ))
    .environmentObject(ListViewModel())
}
