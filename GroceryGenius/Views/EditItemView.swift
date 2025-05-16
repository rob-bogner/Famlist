//
//  EditItemView.swift
//  ShoppingListApp
//
//  Created on 2024-06-14.
//  Last Updated on 2024-06-14.
//
//  A SwiftUI view that allows users to edit an existing item in the shopping list.
//  Provides input fields for item properties such as name, units, measure, price, image symbol, and check status.
//  Includes increment and decrement buttons for units and saves changes back to the shared list view model.
//

import SwiftUI

/// A view for editing an existing item in the shopping list.
struct EditItemView: View {
    
    // MARK: - Properties
    
    /// Environment value to dismiss the current view.
    @Environment(\.dismiss) private var dismiss
    /// Shared list view model object for managing the shopping list.
    @EnvironmentObject var listViewModel: ListViewModel
    /// The item to be edited.
    let item: ItemModel

    /// State variable for the item's name.
    @State private var name: String = ""
    /// State variable for the number of units as a string.
    @State private var units: String = "1"
    /// State variable for the measure unit.
    @State private var measure: String = ""
    /// State variable for the price as a string.
    @State private var price: String = "0.0"
    /// State variable for the image symbol.
    @State private var image: String = ""
    /// State variable for whether the item is checked.
    @State private var isChecked: Bool = false
    /// Focus state for the name text field.
    @FocusState private var isNameFieldFocused: Bool

    /// State variable to hold the selected UIImage from the image picker.
    @State private var selectedImage: UIImage? = nil
    /// State variable to control the presentation of the image picker sheet.
    @State private var isShowingImagePicker: Bool = false

    /// Computed property to convert units string to integer and back.
    private var unitsInt: Int {
        get { Int(units) ?? 1 } // Get integer value from units string or default to 1.
        set { units = String(newValue) } // Set units string from integer value.
    }
    
    /// Formatter to localize price input according to user locale.
    private var priceFormatter: NumberFormatter {
        let formatter = NumberFormatter() // Create a number formatter instance.
        formatter.numberStyle = .decimal // Set style to decimal numbers.
        formatter.locale = Locale.current // Use the current locale for formatting.
        return formatter // Return the configured formatter.
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 16) { // Vertical stack with spacing of 16 points.
            TextField("Enter Item Name", text: $name) // Text field for entering the item name.
                .textFieldStyle(.roundedBorder) // Apply rounded border style to the text field.
                .lineLimit(1) // Limit the text to a single line.
                .focused($isNameFieldFocused) // Bind focus state to isNameFieldFocused.

            HStack { // Horizontal stack for units, measure, and buttons.
                TextField("Units", text: $units) // Text field for entering units.
                    .keyboardType(.numberPad) // Use number pad keyboard for input.
                    .frame(width: 70) // Set fixed width of 70 points.
                    .multilineTextAlignment(.leading) // Align text to the leading edge.
                    .textFieldStyle(.roundedBorder) // Apply rounded border style.

                TextField("Measure", text: $measure) // Text field for measure unit.
                    .multilineTextAlignment(.leading) // Align text to the leading edge.
                    .textFieldStyle(.roundedBorder) // Apply rounded border style.
                    .lineLimit(1) // Limit to a single line.

                Spacer() // Flexible space to push buttons to the right.

                HStack(spacing: 8) { // Horizontal stack for decrement and increment buttons with spacing.
                    Button(action: {
                        decrementUnits() // Call function to decrement units.
                    }) {
                        Image(systemName: "minus.circle") // Display minus circle system image.
                            .font(.title) // Set font size to title.
                            .foregroundColor(Color.accentColor) // Use accent color for the image.
                    }

                    Button(action: {
                        incrementUnits() // Call function to increment units.
                    }) {
                        Image(systemName: "plus.circle") // Display plus circle system image.
                            .font(.title) // Set font size to title.
                            .foregroundColor(Color.accentColor) // Use accent color for the image.
                    }
                }
            }
            .frame(maxWidth: .infinity) // Allow the HStack to expand to maximum width.

            TextField(
                "Price",
                value: Binding(
                    get: {
                        Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0.0 // Convert price string to Double, replacing commas with dots.
                    },
                    set: {
                        price = priceFormatter.string(from: NSNumber(value: $0)) ?? "" // Format Double to localized string.
                    }
                ),
                formatter: priceFormatter // Use the number formatter for the text field.
            )
            .keyboardType(.decimalPad) // Use decimal pad keyboard.
            .textFieldStyle(.roundedBorder) // Apply rounded border style.
            .lineLimit(1) // Limit to a single line.

            TextField("Symbol", text: $image) // Text field for the image symbol.
                .textFieldStyle(.roundedBorder) // Apply rounded border style.
                .lineLimit(1) // Limit to a single line.

            // Show selected image preview if available
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .cornerRadius(10)
                    .padding(.top, 8)
            }

            // Button to add or take a photo
            Button(action: {
                isShowingImagePicker = true
            }) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Add Photo")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    Color.accentColor
                        .cornerRadius(10)
                )
                .foregroundColor(.white)
                .font(.headline)
            }
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePicker(selectedImage: $selectedImage, isPresented: $isShowingImagePicker)
            }

            Toggle("Checked", isOn: $isChecked) // Toggle switch for checked state.
            
            HStack(spacing: 8) { // Horizontal stack for Cancel and Save buttons with spacing.
                Button(action: {
                    dismiss() // Dismiss the view without saving.
                }, label: {
                    Text("Cancel") // Button label.
                        .padding() // Add default padding around the text.
                        .frame(maxWidth: .infinity) // Expand button to maximum width.
                        .background( // Background view for the button.
                            Color.gray // Gray color for background.
                                .cornerRadius(10) // Rounded corners with radius 10.
                        )
                        .foregroundColor(.white) // White text color.
                        .font(.headline) // Headline font style.
                })

                Button(action: {
                    saveChanges() // Save the changes.
                    dismiss() // Dismiss the view after saving.
                }, label: {
                    Text("Save") // Button label.
                        .padding() // Add default padding around the text.
                        .frame(maxWidth: .infinity) // Expand button to maximum width.
                        .background( // Background view for the button.
                            Color.blue // Blue color for background.
                                .cornerRadius(10) // Rounded corners with radius 10.
                        )
                        .foregroundColor(.white) // White text color.
                        .font(.headline) // Headline font style.
                })
            }
            .padding(.top, 35) // Add top padding of 35 points to the button stack.
        }
        .padding(.horizontal) // Add default horizontal padding around the VStack.
        .padding(.vertical, 25) // Add vertical padding of 25 points.
        .frame(maxWidth: .infinity, alignment: .leading) // Expand to max width, align content to leading.
        .frame(maxHeight: .infinity, alignment: .top) // Expand to max height, align content to top.
        .ignoresSafeArea(.keyboard, edges: .bottom) // Ignore safe area for keyboard on bottom edge.
        .navigationTitle("Edit Item") // Set navigation title.
        .onAppear {
            name = item.name // Initialize name state with item's name.
            units = String(item.units) // Initialize units state with item's units as string.
            measure = item.measure // Initialize measure state.
            price = String(item.price) // Initialize price state as string.
            image = item.image // Initialize image state.
            isChecked = item.isChecked // Initialize checked state.
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // Delay to focus name field after view appears.
                isNameFieldFocused = true // Set focus to name text field.
            }
        }
    }
    
    // MARK: - Helper Functions
    
    /// Decreases the number of units by 1, with a minimum of 1.
    private func decrementUnits() {
        var currentUnits = Int(units) ?? 1 // Convert units string to integer or default to 1.
        if currentUnits > 1 { // Only decrement if greater than 1.
            currentUnits -= 1 // Decrement units by 1.
            units = String(currentUnits) // Update units string.
        }
    }

    /// Increases the number of units by 1, up to a maximum of 999.
    private func incrementUnits() {
        var currentUnits = Int(units) ?? 1 // Convert units string to integer or default to 1.
        if currentUnits < 999 { // Only increment if less than 999.
            currentUnits += 1 // Increment units by 1.
            units = String(currentUnits) // Update units string.
        }
    }

    /// Saves the edited changes back to the list model.
    private func saveChanges() {
        let updatedItem = ItemModel( // Create updated item model.
            id: item.id, // Keep the same id.
            image: selectedImage?.jpegData(compressionQuality: 0.8)?.base64EncodedString() ?? image, // Use new image if selected, else keep existing symbol.
            name: name, // Use updated name.
            units: Int(units) ?? 1, // Convert units string to integer.
            measure: measure, // Use updated measure.
            price: Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0.0, // Convert price string to double.
            isChecked: isChecked // Use updated checked state.
        )
        listViewModel.updateItem(updatedItem) // Update the item in the list view model.
    }
}

#Preview {
    EditItemView(item: ItemModel(name: "Milch")) // Preview with sample item named "Milch".
        .environmentObject(ListViewModel()) // Provide environment object for preview.
}
