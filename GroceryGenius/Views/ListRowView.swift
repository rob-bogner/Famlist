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
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale.current
        return formatter
    }
    
    // MARK: - Computed Views
    
    /// Attempts to decode the item's Base64 imageData string.
    /// If successful, displays the decoded image.
    /// Otherwise, displays a default placeholder image.
    private var itemImageView: some View {
        Group {
            // Changed from item.image to item.imageData as per instructions
            if let imageDataString = item.imageData,
               !imageDataString.isEmpty,
               let imageData = Data(base64Encoded: imageDataString),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Image("defaultImage")
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: 50, height: 50)
        .cornerRadius(5)
        .padding(10)
    }
    
    /// View for displaying the name of the item, with strikethrough if checked.
    private var itemNameView: some View {
        Text(item.name)
            .font(.headline)
            .strikethrough(item.isChecked, color: item.isChecked ? Color.accentColor : .none)
            .frame(alignment: .leading)
    }
    
    /// View for displaying additional details like units and price of the item.
    private var itemDetailsView: some View {
        HStack {
            Text("\(item.units) \(item.measure)")
                .frame(alignment: .leading)
            
            Spacer()
            
            Text(priceFormatter.string(from: NSNumber(value: item.price)) ?? "€ 0.00")
        }
        .font(.subheadline)
    }
    
    // MARK: - Body
    
    /// The main body view of the row, composing image, name, and details with styling.
    var body: some View {
        ZStack {
            Color.theme.background
                .ignoresSafeArea()
            
            HStack(alignment: .top) {
                itemImageView
                
                VStack(alignment: .leading) {
                    itemNameView
                    
                    Spacer()
                    
                    itemDetailsView
                }
                .padding(.trailing, 7)
                .padding(.vertical, 7)
            }
            .background(item.isChecked ? Color.theme.buttonFillColor : Color.theme.card)
            .opacity(item.isChecked ? 0.5 : 1)
            .cornerRadius(10)
        }
    }
}

#Preview {
    ListRowView(item: ItemModel(
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
}
