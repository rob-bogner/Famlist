/*
 AddItemView.swift

 GroceryGenius
 Created on: 27.11.2023
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Modal sheet UI for creating a new shopping list item, capturing name, units, and measure, plus an optional photo.

 🛠 Includes:
 - PhotoField for image capture/selection, QuantityMeasureRow for units and measure, validation helpers, and a Save button that persists via ListViewModel.

 🔰 Notes for Beginners:
 - This view is presented as a sheet and writes to the shared ListViewModel. Inputs are validated before saving. Units are kept as String during editing for better UX.
 - The repository is injected into the ListViewModel; this view doesn’t talk to Supabase directly.

 📝 Last Change:
 - Added standardized header and clarified comments. Updated Preview to use PreviewMocks for consistent sample data. No functional changes.
 ------------------------------------------------------------------------

 */

import SwiftUI // Imports SwiftUI to build the add item modal and use property wrappers.

/// A view for adding a new item to the shopping list.
struct AddItemView: View { // Declares the SwiftUI view type for adding items.
    
    // MARK: - Properties
    
    /// Environment dismiss action to close the current view.
    @Environment(\.dismiss) private var dismiss // Allows closing the sheet programmatically.
    
    /// Shared list view model injected as environment object.
    @EnvironmentObject var listViewModel: ListViewModel // Provides actions and data context.
    
    /// State for the entered item name.
    @State private var item: String = "" // Holds the text for the item name.
    
    /// State for the entered number of units, stored as string.
    @State private var units: String = "1" // String to allow partial edits and easy clamping.
    
    /// State for the entered measurement unit.
    @State private var measure: String = "" // Free-form until normalized by view model.
    
    /// Focus state to control keyboard focus on the item text field.
    @FocusState private var isItemFieldFocused: Bool // Focuses name field on appear.

    /// State for the selected image from the image picker.
    @State private var selectedImage: UIImage? = nil // Optional photo to attach.

    @State private var nameError: String? = nil // Holds inline error for name field.
    @State private var unitsError: String? = nil // Holds inline error for units field.

    // MARK: - Body
    
    /// The main body view layout.
    var body: some View { // Composes the modal with form and save button.
        CustomModalView(title: String(localized: "addItem.title"), onClose: { dismiss() }) { // Modal shell with title and close.
            VStack(spacing: 16) { // Vertical layout with spacing between sections.
                ScrollView { // Allows content to scroll if keyboard overlaps.
                    VStack(spacing: 12) { // Form fields stack.
                        PhotoField(image: $selectedImage) // Photo picker field.
                        VStack(alignment: .leading, spacing: 4) { // Name field + error.
                            TextField(String(localized: "field.name.placeholder"), text: $item) // Name input.
                                .textFieldStyle(.roundedBorder) // Rounded border style.
                                .lineLimit(1) // Single-line input.
                                .focused($isItemFieldFocused) // Focus on appear.
                                .overlay( // Error border.
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(nameError == nil ? Color.clear : Color.red, lineWidth: 1) // Red when error.
                                )
                            if let nameError { Text(nameError).font(.caption2).foregroundColor(.red) } // Inline error text.
                        }
                        VStack(alignment: .leading, spacing: 4) { // Units + measure row + error.
                            QuantityMeasureRow(units: $units, measure: $measure) // Units + measure input.
                            if let unitsError { Text(unitsError).font(.caption2).foregroundColor(.red) } // Inline error text.
                        }
                        Spacer(minLength: 0) // Filler to push save button down if content short.
                    }
                    .frame(maxWidth: .infinity, alignment: .leading) // Stretch horizontally.
                    .padding(.horizontal) // Standard horizontal padding.
                    .padding(.vertical, 25) // Top/bottom padding for comfortable spacing.
                }
                PrimaryButton(title: String(localized: "button.addItem")) { // Save button.
                    // Synchronous validation (state updates apply after return; validate locally first)
                    let currentNameError = ItemInputValidator.validateName(item) // Validate name.
                    let currentUnitsError = ItemInputValidator.validateUnits(units) // Validate units.
                    nameError = currentNameError // Update state to show/hide errors.
                    unitsError = currentUnitsError // Update state to show/hide errors.
                    guard currentNameError == nil, currentUnitsError == nil else { return } // Stop if invalid.
                    let sanitized = ItemInputValidator.sanitizedName(item) // Trim whitespace.
                    addItemPressed(sanitizedName: sanitized) // Persist the new item.
                    dismiss() // Close sheet.
                }
                .disabled(!formValid) // Disable when form invalid.
                .padding(.horizontal) // aligned with text fields horizontally
                .padding(.bottom, 16) // Space from bottom edge.
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) // Expand to fill modal.
        }
        .onAppear { isItemFieldFocused = true; validateAll() } // Focus name and validate initial state.
        .onChange(of: item) { _ , _ in validateName() } // Revalidate name on change.
        .onChange(of: units) { _ , _ in validateUnits() } // Revalidate units on change.
        .presentationDetents([.height(500)]) // Preferred modal height for this form.
    }
    
    // MARK: - Validation & Persistence
    
    private var formValid: Bool { nameError == nil && unitsError == nil && !item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } // Form validity aggregate.
    private func validateName() { nameError = ItemInputValidator.validateName(item) } // Validate and store name error.
    private func validateUnits() { unitsError = ItemInputValidator.validateUnits(units) } // Validate and store units error.
    private func validateAll() { validateName(); validateUnits() } // Run all validators.

    /// Adds a new item to the shopping list.
    private func addItemPressed(sanitizedName: String) { // Builds model and delegates to view model.
        let imageBase64 = imageToBase64(selectedImage) // Convert optional image to Base64.
        let newItem = ItemModel( // Build a minimal item.
            imageData: imageBase64, // Optional image data.
            name: sanitizedName, // Trimmed name.
            units: Int(units) ?? 1, // Parse units or default to 1.
            measure: measure, // Free-form measure string.
            price: 0.0, // Default price.
            isChecked: false // New items are unchecked.
        )
        listViewModel.addItem(newItem) // Ask VM to persist via repository.
    }
}

#Preview { // Preview provider for AddItemView. Uses PreviewMocks to provide a realistic ListViewModel with in-memory data.
    AddItemView() // Instantiate the add form.
        .environmentObject(PreviewMocks.makeListViewModelWithSamples()) // Inject a preview VM with sample data.
}
