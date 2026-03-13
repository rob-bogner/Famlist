/*
 AddItemView.swift

 Famlist
 Created on: 27.11.2023
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - SwiftUI sheet for adding new items to shopping list with validation

 🛠 Includes:
 - Photo picker integration
 - Validated name, units, and measure inputs
 - Integration with ItemFormViewModel for shared validation logic
 - Primary button for submission

 🔰 Notes for Beginners:
 - Uses ItemFormViewModel to eliminate validation duplication
 - Dismisses automatically after successful add
 - Focus field ensures keyboard appears for name input on load

 📝 Last Change:
 - Refactored to use ItemFormViewModel and ValidatedTextField components
 ------------------------------------------------------------------------
 */

import SwiftUI // SwiftUI framework for declarative UI

/// View for adding a new item to the shopping list
struct AddItemView: View {

    // MARK: - Environment & Dependencies

    @Environment(\.dismiss) var dismiss // Environment value to dismiss the sheet
    @EnvironmentObject var listViewModel: ListViewModel // Injected list view model for item operations
    @FocusState private var isItemFieldFocused: Bool // Focus state for name field

    // MARK: - State

    @StateObject private var formVM: ItemFormViewModel // Shared form ViewModel

    // MARK: - Init

    /// Called after a new item is successfully added. Used by callers (e.g. ItemSearchView)
    /// to dismiss a parent sheet in addition to this view's own dismiss.
    private let onItemAdded: (() -> Void)?

    /// Creates the view, optionally pre-filling the item name (e.g. from ItemSearchView).
    /// - Parameters:
    ///   - initialName: Pre-filled name from the search field.
    ///   - onItemAdded: Optional callback fired after successful submission (e.g. to close a parent sheet).
    init(initialName: String = "", onItemAdded: (() -> Void)? = nil) {
        _formVM = StateObject(wrappedValue: ItemFormViewModel(initialName: initialName))
        self.onItemAdded = onItemAdded
    }
    
    // MARK: - Body
    
    var body: some View {
        CustomModalView(title: String(localized: "addItem.title"), onClose: { dismiss() }) {
            VStack(spacing: 16) {
                // Scrollable form content
                ScrollView {
                    VStack(spacing: 12) {
                        // Photo picker field
                        PhotoField(image: $formVM.selectedImage)
                        
                        // Validated name field
                        ValidatedTextField(
                            placeholder: String(localized: "field.name.placeholder"),
                            text: $formVM.name,
                            error: formVM.nameError,
                            onChanged: { formVM.validateField(.name) }
                        )
                        .focused($isItemFieldFocused) // Attach focus state
                        
                        // Quantity and measure row with validation
                        VStack(alignment: .leading, spacing: 4) {
                            QuantityMeasureRow(units: $formVM.units, measure: $formVM.measure)
                            if let unitsError = formVM.unitsError {
                                Text(unitsError)
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                        .onChange(of: formVM.units) { _, _ in formVM.validateField(.units) }
                        
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 25)
                }
                
                // Submit button
                PrimaryButton(title: String(localized: "button.addItem")) {
                    formVM.validateAll()
                    guard formVM.isValid else { return }

                    let newItem = formVM.toItemModel()
                    listViewModel.addItem(newItem)
                    // dismiss() first so AddItemView is gone before the parent sheet dismisses
                    dismiss()
                    onItemAdded?()
                }
                .disabled(!formVM.isValid)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear { 
            isItemFieldFocused = true // Focus name field when view appears
            formVM.validateAll() 
        }
        .presentationDetents([.height(500)])
    }
}

// MARK: - Previews

#Preview {
    AddItemView()
        .environmentObject(PreviewMocks.makeListViewModelWithSamples())
}

#Preview("With initial name") {
    AddItemView(initialName: "Milch")
        .environmentObject(PreviewMocks.makeListViewModelWithSamples())
}
