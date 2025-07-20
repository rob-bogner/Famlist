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

    /// Whether the photo picker sheet is open
    @State private var isShowingImagePicker: Bool = false

    /// The type of photo picker (camera or gallery)
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary

    /// Whether to show the dialog to pick camera/gallery
    @State private var isShowingSourceDialog: Bool = false

    /// Focus management for the first text field (item name)
    @FocusState private var isNameFieldFocused: Bool

    /// Localized number formatter for price input
    private var priceFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        return formatter
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) { // Vertical stack for all content, spacing between fields
            header(dismiss: { dismiss() }) // Header with title and close button

            ScrollView { // Allows view to scroll if keyboard is open or content is long
                VStack(spacing: 12) { // Stack for all editable fields

                    // --- Image Preview & Picker ---
                    if let selectedImage = selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .roundedCorners(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            )
                            .onTapGesture {
                                // Tapping the image lets the user pick a new one
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
                            .roundedCorners(8)
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

                    // --- Editable Fields ---
                    // Name
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1)
                        .focused($isNameFieldFocused)

                    // Brand
                    TextField("Brand", text: $brand)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1)

                    // Product Description
                    TextField("Product Description", text: $productDescription)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1)

                    // Category
                    TextField("Category", text: $category)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1)

                    // --- Units, Measure, and Increment/Decrement Buttons (like AddItemView) ---
                    HStack {
                        // Text field for number of units
                        TextField("Units", text: $units)
                            .keyboardType(.numberPad)
                            .frame(width: 70)
                            .multilineTextAlignment(.leading)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1)

                        // Text field for measurement unit (e.g., "kg", "L")
                        TextField("Measure", text: $measure)
                            .multilineTextAlignment(.leading)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1)

                        Spacer()

                        // Increment/Decrement Buttons
                        HStack(spacing: 10) {
                            Button(action: decrementUnits) {
                                Image(systemName: "minus.circle")
                                    .font(.title)
                                    .foregroundColor(Color.accentColor)
                            }
                            Button(action: incrementUnits) {
                                Image(systemName: "plus.circle")
                                    .font(.title)
                                    .foregroundColor(Color.accentColor)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Price
                    TextField(
                        "Price",
                        value: Binding(
                            get: {
                                Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                            },
                            set: {
                                price = priceFormatter.string(from: NSNumber(value: $0)) ?? ""
                            }
                        ),
                        formatter: priceFormatter
                    )
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // --- Save Button ---
            Button(action: {
                saveChanges() // Save all edited fields to the item
                dismiss() // Close the sheet
            }, label: {
                Text("Save")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.roundedCorners(10))
                    .foregroundColor(.white)
                    .font(.headline)
            })
            .padding(.top, 8)
        }
        .padding(.horizontal)
        .padding(.vertical, 25)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            // Initialize all fields from the current item
            name = item.name
            brand = item.brand ?? ""
            productDescription = item.productDescription ?? ""
            category = item.category ?? ""
            units = String(item.units)
            measure = item.measure
            price = String(item.price)
            isChecked = item.isChecked

            // Load image from base64 string if available
            if let imageDataString = item.imageData,
               let imageData = Data(base64Encoded: imageDataString),
               let uiImage = UIImage(data: imageData) {
                selectedImage = uiImage
            } else {
                selectedImage = nil
            }

        }
        .presentationDetents([.height(570)]) // Height similar to AddItemView
        .confirmationDialog("Select Photo Source", isPresented: $isShowingSourceDialog, titleVisibility: .visible) {
            Button("Take Photo") {
                imagePickerSourceType = .camera
                isShowingImagePicker = true
            }
            Button("Choose from Gallery") {
                imagePickerSourceType = .photoLibrary
                isShowingImagePicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Helper Functions

    /// Save all changes to the item and update the model
    private func saveChanges() {
        listViewModel.updateItemFromInput(
            id: item.id,
            name: name,
            units: units,
            measure: measure,
            price: price,
            isChecked: isChecked,
            category: category,
            productDescription: productDescription,
            brand: brand,
            image: selectedImage
        )
    }

    /// Helper to dismiss the keyboard
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Header view with centered title and close button.
    private func header(dismiss: @escaping () -> Void) -> some View {
        HStack {
            Spacer(minLength: 0)
            Text("Edit Item")
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
    
    // MARK: - Increment/Decrement Logic
    
    /// Decreases the number of units by 1, minimum 1.
    private func decrementUnits() {
        var currentUnits = Int(units) ?? 1
        if currentUnits > 1 {
            currentUnits -= 1
            units = String(currentUnits)
        }
    }
    
    /// Increases the number of units by 1, max 999.
    private func incrementUnits() {
        var currentUnits = Int(units) ?? 1
        if currentUnits < 999 {
            currentUnits += 1
            units = String(currentUnits)
        }
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
