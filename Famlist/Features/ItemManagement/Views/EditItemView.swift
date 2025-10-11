/*
 EditItemView.swift

 GroceryGenius
 Created on: 27.11.2023
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet UI for editing an existing shopping list item (photo, name, brand, description, category, units, measure, price).

 🛠 Includes:
 - Photo picker, validated inputs, quantity+measure controls, and a Save button that persists via the ListViewModel.

 🔰 Notes for Beginners:
 - The view receives the item to edit and writes changes back through the shared ListViewModel.
 - Validation shows inline error messages; actual persistence happens asynchronously in the view model.

 📝 Last Change:
 - Standardized file header and preview updated to use PreviewMocks for consistent data. No functional changes.
 ------------------------------------------------------------------------
 */

import SwiftUI // Imports SwiftUI to build the edit item sheet and use property wrappers.

/// A view for editing an existing item in the shopping list.
/// All properties can be edited, including name, brand, description, category, units, measure, price, and photo.
struct EditItemView: View { // Declares the SwiftUI view for editing items.

    // MARK: - Properties
    /// Dismiss action to close the sheet
    @Environment(\.dismiss) private var dismiss // Provides a way to programmatically close the sheet.

    /// The view model for the list, needed to update the item
    @EnvironmentObject var listViewModel: ListViewModel // Shared view model to persist updates.

    /// The item being edited
    let item: ItemModel // The model snapshot passed into the editor.

    // Editable fields, initialized from the current item's properties
    @State private var name: String = "" // Item name being edited.
    @State private var brand: String = "" // Editable brand text.
    @State private var productDescription: String = "" // Editable description text.
    @State private var category: String = "" // Editable category text.
    @State private var units: String = "1" // Units kept as String to allow partial typing.
    @State private var measure: String = "" // Editable measurement text.
    @State private var price: String = "0.0" // Editable price text in dot-decimal.
    @State private var isChecked: Bool = false // Toggle whether the item is checked.

    /// Holds the currently selected photo (UIImage)
    @State private var selectedImage: UIImage? = nil // Optional image chosen by the user.

    /// Focus management for the first text field (item name)
    @FocusState private var isNameFieldFocused: Bool // Controls the keyboard focus for the name field.

    @State private var nameError: String? = nil // Inline error message for the name field.
    @State private var unitsError: String? = nil // Inline error message for units.
    @State private var priceError: String? = nil // Inline error message for price.

    // MARK: - Body

    var body: some View { // Composes the modal with form sections and save button.
        CustomModalView(title: String(localized: "editItem.title"), onClose: { dismiss() }) { // Modal header with title and close.
            VStack(spacing: DS.Spacing.l) { // Vertical layout with large spacing between sections.
                ScrollView { // Allows the form to scroll when the keyboard is visible.
                    VStack(spacing: DS.Spacing.m) { // Stack all input fields with medium spacing.
                        PhotoField(image: $selectedImage) // Reusable photo picker field.
                        VStack(alignment: .leading, spacing: 4) { // Name field with validation styling.
                            TextField(String(localized: "field.name.placeholder"), text: $name) // Editable name field.
                                .textFieldStyle(.roundedBorder) // Rounded style for clarity.
                                .lineLimit(1) // Single-line input.
                                .focused($isNameFieldFocused) // Focus this field when the screen appears.
                                .overlay( // Red border when validation fails.
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(nameError == nil ? Color.clear : Color.red, lineWidth: 1) // Show red border when name invalid.
                                )
                            if let nameError { Text(nameError).font(.caption2).foregroundColor(.red) } // Show validation message for name.
                        }
                        TextField(String(localized: "field.brand.placeholder"), text: $brand) // Brand input field.
                            .textFieldStyle(.roundedBorder) // Rounded look.
                            .lineLimit(1) // Single-line.
                        TextField(String(localized: "field.description.placeholder"), text: $productDescription) // Description field.
                            .textFieldStyle(.roundedBorder) // Rounded look.
                            .lineLimit(1) // Single-line.
                        TextField(String(localized: "field.category.placeholder"), text: $category) // Category field.
                            .textFieldStyle(.roundedBorder) // Rounded look.
                            .lineLimit(1) // Single-line.
                        VStack(alignment: .leading, spacing: 4) { // Units + measure row with validation.
                            QuantityMeasureRow(units: $units, measure: $measure) // Reusable units/measure control.
                            if let unitsError { Text(unitsError).font(.caption2).foregroundColor(.red) } // Show units validation.
                        }
                        VStack(alignment: .leading, spacing: 4) { // Price input with validation.
                            PriceField(price: $price, errorMessage: priceError) // Locale-aware price field.
                            if let priceError { Text(priceError).font(.caption2).foregroundColor(.red) } // Show price validation.
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading) // Stretch to container width.
                    .padding(.horizontal) // Standard horizontal padding.
                    .padding(.vertical, 25) // Comfortable vertical padding.
                }
                PrimaryButton(title: String(localized: "button.save")) { // Save changes button.
                    // Validation
                    let currentNameError = ItemInputValidator.validateName(name) // Validate name string.
                    let currentUnitsError = ItemInputValidator.validateUnits(units) // Validate units string.
                    let currentPriceError = ItemInputValidator.validatePrice(price) // Validate price string.
                    nameError = currentNameError // Update visible name error.
                    unitsError = currentUnitsError // Update visible units error.
                    priceError = currentPriceError // Update visible price error.
                    guard currentNameError == nil, currentUnitsError == nil, currentPriceError == nil else { return } // Stop when invalid.
                    saveChanges() // Persist edits through the view model.
                    dismiss() // Close the sheet.
                }
                .disabled(!formValid) // Disable the button if any validation fails.
                .padding(.horizontal) // Align with form padding.
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) // Stretch to fill sheet.
            .onAppear { populateFields(); validateAll() } // Initialize fields from the model and perform first validation.
            .onChange(of: name) { _ , _ in validateName() } // Revalidate on name changes.
            .onChange(of: units) { _ , _ in validateUnits() } // Revalidate on units changes.
            .onChange(of: price) { _ , _ in validatePrice() } // Revalidate on price changes.
            .presentationDetents([.height(570)]) // Preferred heights for this sheet.
        }
        .presentationBackground(Color.theme.card) // Force a consistent backdrop instead of OS-tinted material.
        .background(Color.theme.card) // Secondary fallback when presentationBackground is unavailable.
    }

    // MARK: - Validation Helpers

    private var formValid: Bool { nameError == nil && unitsError == nil && priceError == nil } // All validators must pass.
    private func validateName() { nameError = ItemInputValidator.validateName(name) } // Validate name and store error.
    private func validateUnits() { unitsError = ItemInputValidator.validateUnits(units) } // Validate units and store error.
    private func validatePrice() { priceError = ItemInputValidator.validatePrice(price) } // Validate price and store error.
    private func validateAll() { validateName(); validateUnits(); validatePrice() } // Run all validations.

    // MARK: - Populate & Save

    /// Initializes the editable fields with the current item's properties
    private func populateFields() { // Pre-fill UI state from model values.
        name = item.name // Copy current name.
        brand = item.brand ?? "" // Copy brand or empty.
        productDescription = item.productDescription ?? "" // Copy description or empty.
        category = item.category ?? "" // Copy category or empty.
        units = String(item.units) // Start with existing units.
        measure = item.measure // Existing measure string.
        price = String(item.price) // Convert price to string.
        isChecked = item.isChecked // Existing checked state.

        // Load image from base64 string if available
        if let img = ImageCache.shared.image(fromBase64: item.imageData) { // Decode image once if present.
            selectedImage = img // Use decoded image in the UI.
        }
    }

    /// Save all changes to the item and update the model
    private func saveChanges() { // Build an updated model and delegate to the view model.
        let sanitizedName = ItemInputValidator.sanitizedName(name) // Trim name.
        // Convert selected image to base64 string, if available
        let imageBase64 = selectedImage?.jpegData(compressionQuality: 0.8)?.base64EncodedString() // Encode image.
        // Create the updated ItemModel
        let updatedItem = ItemModel(
            id: item.id, // Keep original id.
            imageData: imageBase64, // New or nil image data.
            name: sanitizedName, // Updated name.
            units: Int(units) ?? 1, // Updated units.
            measure: measure, // Updated measure string.
            price: Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0.0, // Normalize and parse price.
            isChecked: isChecked, // Keep or change checked state.
            category: category, // Updated category.
            productDescription: productDescription, // Updated description.
            brand: brand // Updated brand.
        )
        listViewModel.updateItem(updatedItem) // Update via the view model (repository handles persistence).
    }
}

#Preview { // Preview for EditItemView using the new layout and logic.
    EditItemView(item: ItemModel( // Construct a sample item for preview.
        id: UUID().uuidString,
        imageData: nil,
        name: "Milk",
        units: 1,
        measure: "l",
        price: 1.99,
        isChecked: false,
        category: "Dairy",
        productDescription: "Organic whole milk 3.5%",
        brand: "Brand"
    ))
    .environmentObject(PreviewMocks.makeListViewModelWithSamples()) // Provide preview view model with sample data.
}
