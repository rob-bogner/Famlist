/*
 GroceryGenius
 ListRowView.swift
 Created by Robert Bogner on 27.11.23.
 
 Defines the appearance and behavior of a single row in the grocery list.
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
    
    /// View for displaying the image of the item.
    private var itemImageView: some View {
        Image(item.image.isEmpty ? "defaultImage" : item.image)
            .resizable()
            .scaledToFit()
            .frame(width: 50, height: 50)
            .cornerRadius(5)
            .padding(10)
    }
    
    /// View for displaying the name of the item, with strikethrough if checked.
    private var itemNameView: some View {
        Text(item.name)
            .font(.headline)
            .strikethrough(item.isChecked, color: item.isChecked ? Color.black : .none)
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
    ListRowView(item: MockData.sampleItem)
}
