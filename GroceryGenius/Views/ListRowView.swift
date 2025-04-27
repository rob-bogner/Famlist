/*
 GroceryGenius
 ListRowView.swift
 Created: 27.11.23
 Last Updated: 29.04.24

 File Overview:
 This file defines the ListRowView struct, which represents a single row in the grocery list.
 It displays the item's image, name, units, measure, and price.
 The row appearance changes based on whether the item is checked or not.
*/

import SwiftUI

/// Represents a single row in the list view, displaying details of an item.
struct ListRowView: View {
    
    // MARK: - Properties
    
    /// The item model that this row represents.
    let item: ItemModel
    
    /// Formatter to display the price in localized currency format.
    private var priceFormatter: NumberFormatter {
        let formatter = NumberFormatter() // Create a NumberFormatter instance
        formatter.numberStyle = .currency // Set the formatter style to currency
        formatter.currencyCode = "EUR" // Set the currency code to Euro
        formatter.locale = Locale.current // Use the current locale for formatting
        return formatter // Return the configured formatter
    }
    
    // MARK: - Computed Views
    
    /// View for displaying the image of the item.
    private var itemImageView: some View {
        Image(item.image.isEmpty ? "defaultImage" : item.image) // Use default image if item image is empty
            .resizable() // Make the image resizable
            .scaledToFit() // Scale the image to fit its frame while maintaining aspect ratio
            .frame(width: 50, height: 50) // Set the frame size to 50x50 points
            .cornerRadius(5) // Apply a corner radius of 5 points
            .padding(10) // Add padding of 10 points around the image
    }
    
    /// View for displaying the name of the item, with strikethrough if checked.
    private var itemNameView: some View {
        Text(item.name) // Display the item's name
            .font(.headline) // Use headline font style
            .strikethrough(item.isChecked, color: item.isChecked ? Color.black : .none) // Apply strikethrough if checked
            .frame(alignment: .leading) // Align text to the leading edge
    }
    
    /// View for displaying additional details like units and price of the item.
    private var itemDetailsView: some View {
        HStack { // Horizontal stack for units/measure and price
            Text("\(item.units) \(item.measure)") // Display units and measure
                .frame(alignment: .leading) // Align text to leading edge
            
            Spacer() // Push price text to the right
            
            Text(priceFormatter.string(from: NSNumber(value: item.price)) ?? "€ 0.00") // Display formatted price or fallback
        }
        .font(.subheadline) // Use subheadline font style for details
    }
    
    // MARK: - Body
    
    /// The main body view of the row, composing image, name, and details with styling.
    var body: some View {
        ZStack { // Use ZStack to layer background and content
            Color.theme.background // Set background color from theme
                .ignoresSafeArea() // Extend background to ignore safe area
            
            HStack(alignment: .top) { // Horizontal stack aligning items to top
                itemImageView // Show item image
                
                VStack(alignment: .leading) { // Vertical stack aligned to leading edge
                    itemNameView // Show item name
                    
                    Spacer() // Push details to bottom
                    
                    itemDetailsView // Show item details
                }
                .padding(.trailing, 7) // Add 7 points trailing padding
                .padding(.vertical, 7) // Add 7 points vertical padding
            }
            .background(item.isChecked ? Color.theme.buttonFillColor : Color.theme.card) // Set background color based on checked state
            .opacity(item.isChecked ? 0.5 : 1) // Adjust opacity if checked
            .cornerRadius(10) // Apply corner radius of 10 points
        }
    }
}

#Preview {
    ListRowView(item: MockData.sampleItem) // Preview with sample item
}
