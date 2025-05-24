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
    @State private var selectedImage: UIImage? = nil // Store selected image
    
    /// State to control the presentation of the image picker sheet.
    @State private var isShowingImagePicker: Bool = false // Flag to show image picker

    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary // Steuert Kamera oder Galerie
    @State private var isShowingSourceDialog: Bool = false // Zeigt Auswahl-Dialog für Quelle an

    // MARK: - Body
    
    /// The main body view layout.
    var body: some View {
        VStack(spacing: 16) { // Vertical stack with spacing between elements
            header(dismiss: { dismiss() })
            ScrollView {
                VStack(spacing: 12) { // Inner vertical stack for inputs
                    
                    if let selectedImage = selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            )
                            .onTapGesture {
                                // Optional: Bild antippen, um Bildauswahl erneut zu öffnen
                                dismissKeyboard()
                                isShowingSourceDialog = true
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Button(action: {
                            dismissKeyboard()
                            isShowingSourceDialog = true
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                                    .foregroundColor(.gray)
                                Text("Add Photo")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 100, height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .sheet(isPresented: $isShowingImagePicker) {
                            ImagePicker(selectedImage: $selectedImage, isPresented: $isShowingImagePicker, sourceType: imagePickerSourceType)
                        }
                    }
                    
                    // Text field for entering the item name
                    TextField("Enter Item Name", text: $item)
                        .textFieldStyle(.roundedBorder) // Apply rounded border style
                        .lineLimit(1) // Limit input to one line
                        .focused($isItemFieldFocused) // Bind focus state to this text field

                    HStack { // Horizontal stack for units, measure, and buttons
                        
                        // Text field for number of units
                        TextField("Units", text: $units)
                            .keyboardType(.numberPad) // Use number pad keyboard
                            .frame(width: 70) // Fixed width for units input
                            .multilineTextAlignment(.leading) // Align text to leading edge
                            .textFieldStyle(.roundedBorder) // Rounded border style
                            .lineLimit(1) // Limit input to one line

                        // Text field for measurement unit
                        TextField("Measure", text: $measure)
                            .multilineTextAlignment(.leading) // Align text to leading edge
                            .textFieldStyle(.roundedBorder) // Rounded border style
                            .lineLimit(1) // Limit input to one line

                        Spacer() // Push buttons to the right

                        // Buttons to increment and decrement units
                        HStack(spacing: 10) {
                            Button(action: decrementUnits) { // Decrement units action
                                Image(systemName: "minus.circle") // Minus icon
                                    .font(.title) // Title font size
                                    .foregroundColor(Color.accentColor) // Accent color
                            }

                            Button(action: incrementUnits) { // Increment units action
                                Image(systemName: "plus.circle") // Plus icon
                                    .font(.title) // Title font size
                                    .foregroundColor(Color.accentColor) // Accent color
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading) // Align HStack leading with max width


                    Spacer() // Restore natural spacing and push button down

                    addItemButton // Add item button view
                }
                .frame(maxWidth: .infinity, alignment: .leading) // Align inner VStack leading with max width
            }
        }
        .padding(.horizontal) // Apply horizontal padding
        .padding(.vertical, 25) // Apply vertical padding of 25 points
        .frame(maxWidth: .infinity, alignment: .leading) // Align main VStack leading with max width
        .frame(maxHeight: .infinity, alignment: .top) // Align main VStack top with max height
        .onAppear {
            isItemFieldFocused = true // Automatically focus item name field on appear
        }
        .presentationDetents([.height(500)]) // Fix sheet height to avoid layout compression when image picker is active
        .confirmationDialog("Bild auswählen", isPresented: $isShowingSourceDialog, titleVisibility: .visible) {
            Button("Foto aufnehmen") {
                imagePickerSourceType = .camera
                isShowingImagePicker = true
            }
            Button("Aus Galerie wählen") {
                imagePickerSourceType = .photoLibrary
                isShowingImagePicker = true
            }
            Button("Abbrechen", role: .cancel) {}
        }
    }
    
    // MARK: - Subviews
    
    /// Button to add the item to the list.
    private var addItemButton: some View {
        Button(action: {
            addItemPressed() // Call function to add item
            dismiss() // Dismiss the current view after adding
        }, label: {
            Text("Add Item to List") // Button label
                .padding() // Add padding inside button
                .frame(maxWidth: .infinity) // Make button take full width
                .background( // Background color with corner radius
                    Color.blue
                        .cornerRadius(10)
                )
                .foregroundColor(.white) // Set text color to white
                .font(.headline) // Use headline font style
        })
    }
    
    // MARK: - Functions
    
    /// Adds a new item to the shopping list.
    private func addItemPressed() {
        // Convert selected UIImage to Base64 string for storage
        let imageBase64 = selectedImage?.jpegData(compressionQuality: 0.8)?.base64EncodedString() ?? ""
        
        let newItem = ItemModel(
            image: imageBase64, // Store image as Base64 string
            name: item, // Item name from input
            units: Int(units) ?? 1, // Convert units string to Int, default 1
            measure: measure, // Measurement unit from input
            price: 0.0, // Default price 0.0
            isChecked: false // Default unchecked state
        )
        listViewModel.addItem(newItem) // Add new item to list view model
    }

    /// Decreases the number of units by 1, with a minimum of 1.
    private func decrementUnits() {
        var currentUnits = Int(units) ?? 1 // Parse units string or default to 1
        if currentUnits > 1 { // Only decrement if greater than 1
            currentUnits -= 1 // Decrement units
            units = String(currentUnits) // Update units string
        }
    }

    /// Increases the number of units by 1, up to a maximum of 999.
    private func incrementUnits() {
        var currentUnits = Int(units) ?? 1 // Parse units string or default to 1
        if currentUnits < 999 { // Only increment if less than 999
            currentUnits += 1 // Increment units
            units = String(currentUnits) // Update units string
        }
    }
    
    /// Programmatically dismisses the keyboard.
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// Header view with centered title and close button. Dismiss-Closure wird weitergereicht.
    private func header(dismiss: @escaping () -> Void) -> some View {
        HStack {
            Spacer(minLength: 0)
            Text("Add new Item")
                .font(.title2)
                .foregroundColor(.teal)
                .frame(maxWidth: .infinity, alignment: .center)
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(.gray)
                    .padding(6)
                    .background(Circle().fill(Color(white: 0.95)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }
}

#Preview {
    /// Preview provider for AddItemView.
    AddItemView()
        .environmentObject(ListViewModel()) // Inject list view model for preview
}
