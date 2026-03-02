/*
 EditItemView.swift

 Famlist
 Created on: 27.11.2023
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet UI for editing an existing shopping list item (photo, name, brand, description, category, units, measure, price).

 🛠 Includes:
 - Photo picker, validated inputs, quantity+measure controls, and a Save button that persists via the ListViewModel.
 - Uses ItemFormViewModel for shared validation logic with AddItemView.

 🔰 Notes for Beginners:
 - The view receives the item to edit and writes changes back through the shared ListViewModel.
 - Validation shows inline error messages; actual persistence happens asynchronously in the view model.

 📝 Last Change:
 - Refactored to use ItemFormViewModel and ValidatedTextField to eliminate code duplication.
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

    /// Shared form ViewModel for validation and state management
    @StateObject private var formVM: ItemFormViewModel
    
    // MARK: - Initializer
    
    init(item: ItemModel) {
        self.item = item
        _formVM = StateObject(wrappedValue: ItemFormViewModel(item: item))
    }

    // MARK: - Body

    var body: some View { // Composes the modal with form sections and save button.
        CustomModalView(title: String(localized: "editItem.title"), onClose: { dismiss() }) { // Modal header with title and close.
            VStack(spacing: DS.Spacing.l) { // Vertical layout with large spacing between sections.
                ScrollView { // Allows the form to scroll when the keyboard is visible.
                    VStack(spacing: DS.Spacing.m) { // Stack all input fields with medium spacing.
                        PhotoField(image: $formVM.selectedImage) // Reusable photo picker field.
                        
                        ValidatedTextField(
                            placeholder: String(localized: "field.name.placeholder"),
                            text: $formVM.name,
                            error: formVM.nameError,
                            onChanged: { formVM.validateField(.name) }
                        )
                        
                        TextField(String(localized: "field.brand.placeholder"), text: $formVM.brand) // Brand input field.
                            .textFieldStyle(.roundedBorder) // Rounded look.
                            .lineLimit(1) // Single-line.
                        TextField(String(localized: "field.description.placeholder"), text: $formVM.productDescription) // Description field.
                            .textFieldStyle(.roundedBorder) // Rounded look.
                            .lineLimit(1) // Single-line.
                        TextField(String(localized: "field.category.placeholder"), text: $formVM.category) // Category field.
                            .textFieldStyle(.roundedBorder) // Rounded look.
                            .lineLimit(1) // Single-line.
                        VStack(alignment: .leading, spacing: 4) { // Units + measure row with validation.
                            QuantityMeasureRow(units: $formVM.units, measure: $formVM.measure) // Reusable units/measure control.
                            if let unitsError = formVM.unitsError { Text(unitsError).font(.caption2).foregroundColor(.red) } // Show units validation.
                        }
                        .onChange(of: formVM.units) { _, _ in formVM.validateField(.units) }
                        
                        VStack(alignment: .leading, spacing: 4) { // Price input with validation.
                            PriceField(price: $formVM.price, errorMessage: formVM.priceError) // Locale-aware price field.
                            if let priceError = formVM.priceError { Text(priceError).font(.caption2).foregroundColor(.red) } // Show price validation.
                        }
                        .onChange(of: formVM.price) { _, _ in formVM.validateField(.price) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading) // Stretch to container width.
                    .padding(.horizontal) // Standard horizontal padding.
                    .padding(.vertical, 25) // Comfortable vertical padding.
                }
                PrimaryButton(title: String(localized: "button.save")) { // Save changes button.
                    formVM.validateAll()
                    guard formVM.isValid else { return }
                    
                    let updatedItem = formVM.toItemModel(
                        existingId: item.id, 
                        listId: item.listId,
                        ownerPublicId: item.ownerPublicId
                    )
                    listViewModel.updateItem(updatedItem)
                    dismiss()
                }
                .disabled(!formVM.isValid) // Disable the button if any validation fails.
                .padding(.horizontal) // Align with form padding.
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) // Stretch to fill sheet.
            .onAppear { formVM.validateAll() } // Perform first validation.
            .presentationDetents([.height(570)]) // Preferred heights for this sheet.
        }
        .presentationBackground(Color.theme.card) // Force a consistent backdrop instead of OS-tinted material.
        .background(Color.theme.card) // Secondary fallback when presentationBackground is unavailable.
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
