// MARK: - AddItemView.swift

/*
 AddItemView.swift

 GroceryGenius
 Created on: 27.11.2023
 Last updated on: 26.04.2025

 ------------------------------------------------------------------------
 📄 File Overview:

 This file defines the view used to add a new item to the shopping list.
 It captures user input like item name, number of units, and measurement unit.

 🛠 Includes:
 - Text fields for entering item information
 - Plus and minus buttons to adjust the number of units
 - Add item button to save the new item
 - Focus management to auto-focus the item name field
 - Now supports choosing image from camera or photo library

 🔰 Notes for Beginners:
 - `@EnvironmentObject` injects shared data (ListViewModel).
 - `@FocusState` helps to control the keyboard focus programmatically.
 - `@State` is used to handle local temporary UI state.
 ------------------------------------------------------------------------
*/

import SwiftUI // Import SwiftUI framework for UI components

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
    /// State to control the presentation of the image picker sheet.
    @State private var isShowingImagePicker: Bool = false // (unused after refactor) lässt vorerst stehen falls extern referenziert
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isShowingSourceDialog: Bool = false

    // MARK: - Body
    
    /// The main body view layout.
    var body: some View {
        CustomModalView(title: "Add new Item", onClose: { dismiss() }) {
            VStack(spacing: 16) {
                ScrollView {
                    VStack(spacing: 12) {
                        PhotoField(image: $selectedImage)
                        TextField("Enter Item Name", text: $item)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1)
                            .focused($isItemFieldFocused)
                        QuantityMeasureRow(units: $units, measure: $measure)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 25)
                }
                Spacer(minLength: 0)
                PrimaryButton(title: "Add Item to List") {
                    addItemPressed(); dismiss()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { isItemFieldFocused = true }
        .presentationDetents([.height(500)])
    }
    
    // MARK: - Functions
    
    /// Adds a new item to the shopping list.
    private func addItemPressed() {
        let imageBase64 = imageToBase64(selectedImage) ?? ""
        let newItem = ItemModel(
            imageData: imageBase64,
            name: item,
            units: Int(units) ?? 1,
            measure: measure,
            price: 0.0,
            isChecked: false
        )
        listViewModel.addItem(newItem)
    }
    
    /// Programmatically dismisses the keyboard.
    private func dismissKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
}

#Preview {
    /// Preview provider for AddItemView.
    AddItemView()
        .environmentObject(ListViewModel()) // Inject list view model for preview
}
