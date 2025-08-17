// MARK: - AddItemView.swift

/*
 File: AddItemView.swift
 Project: GroceryGenius
 Created: 27.11.2023
 Last Updated: 17.08.2025

 Overview:
 Modal sheet for creating a new shopping list item. Captures basic fields (name, units, measure) plus optional photo.

 Responsibilities / Includes:
 - Photo picker (camera / library) via PhotoField
 - Text inputs for name + numeric units + measure selection
 - Inline validation (name, units) with error hints
 - Persist new ItemModel through ListViewModel
 - Automatic initial focus on name field

 Design Notes:
 - Units kept as String for lenient incremental validation and to avoid premature coercion
 - Validation performed synchronously on submit; state errors gate save button enablement
 - Dismiss logic handled by parent sheet; internal view triggers via environment dismiss

 Possible Enhancements:
 - Add category / price / brand inputs (currently covered only in edit)
 - Add async image compression pipeline
 - Provide haptic feedback on successful addition
*/

import SwiftUI

/// A view for adding a new item to the shopping list.
struct AddItemView: View {
    
    // MARK: - Properties
    
    /// Environment dismiss action to close the current view.
    @Environment(\.dismiss) private var dismiss
    
    /// Shared list view model injected as environment object.
    @EnvironmentObject var listViewModel: ListViewModel
    
    /// State for the entered item name.
    @State private var item: String = ""
    
    /// State for the entered number of units, stored as string.
    @State private var units: String = "1"
    
    /// State for the entered measurement unit.
    @State private var measure: String = ""
    
    /// Focus state to control keyboard focus on the item text field.
    @FocusState private var isItemFieldFocused: Bool

    /// State for the selected image from the image picker.
    @State private var selectedImage: UIImage? = nil

    @State private var nameError: String? = nil
    @State private var unitsError: String? = nil

    // MARK: - Body
    
    /// The main body view layout.
    var body: some View {
        CustomModalView(title: String(localized: "addItem.title"), onClose: { dismiss() }) {
            VStack(spacing: 16) {
                ScrollView {
                    VStack(spacing: 12) {
                        PhotoField(image: $selectedImage)
                        VStack(alignment: .leading, spacing: 4) {
                            TextField(String(localized: "field.name.placeholder"), text: $item)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(1)
                                .focused($isItemFieldFocused)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(nameError == nil ? Color.clear : Color.red, lineWidth: 1)
                                )
                            if let nameError { Text(nameError).font(.caption2).foregroundColor(.red) }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            QuantityMeasureRow(units: $units, measure: $measure)
                            if let unitsError { Text(unitsError).font(.caption2).foregroundColor(.red) }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 25)
                }
                PrimaryButton(title: String(localized: "button.addItem")) {
                    // Synchronous validation (state updates apply after return; validate locally first)
                    let currentNameError = ItemInputValidator.validateName(item)
                    let currentUnitsError = ItemInputValidator.validateUnits(units)
                    nameError = currentNameError
                    unitsError = currentUnitsError
                    guard currentNameError == nil, currentUnitsError == nil else { return }
                    let sanitized = ItemInputValidator.sanitizedName(item)
                    addItemPressed(sanitizedName: sanitized)
                    dismiss()
                }
                .disabled(!formValid)
                .padding(.horizontal) // aligned with text fields horizontally
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear { isItemFieldFocused = true; validateAll() }
        .onChange(of: item) { _ , _ in validateName() }
        .onChange(of: units) { _ , _ in validateUnits() }
        .presentationDetents([.height(500)])
    }
    
    // MARK: - Validation & Persistence
    
    private var formValid: Bool { nameError == nil && unitsError == nil && !item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private func validateName() { nameError = ItemInputValidator.validateName(item) }
    private func validateUnits() { unitsError = ItemInputValidator.validateUnits(units) }
    private func validateAll() { validateName(); validateUnits() }

    /// Adds a new item to the shopping list.
    private func addItemPressed(sanitizedName: String) {
        let imageBase64 = imageToBase64(selectedImage) ?? ""
        let newItem = ItemModel(
            imageData: imageBase64,
            name: sanitizedName,
            units: Int(units) ?? 1,
            measure: measure,
            price: 0.0,
            isChecked: false
        )
        listViewModel.addItem(newItem)
    }
}

#Preview {
    /// Preview provider for AddItemView.
    AddItemView()
        .environmentObject(ListViewModel()) // Inject list view model for preview
}
