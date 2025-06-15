// GroceryGenius
// ListRowView.swift
// Created on: 27.11.2023
// Last updated on: 31.05.2025
//
// ------------------------------------------------------------------------
// 📄 File Overview:
//
// This file defines the row view for a single shopping list item,
// providing modern styling, theming, and all core interactions.
// Each row can display an item photo, item details, and a checkmark.
//
// 🖌️ Modern UI Features:
// - Theme-based design for consistent light and dark mode support
// - Accent color highlights for checkmark and important actions
// - Displays product image or placeholder
// - Product photo can be tapped to open a fullscreen modal preview
// - Strikethrough in accent color for checked items
//
// 🧑‍💻 Developer Notes:
// - Designed to be used inside ListView and ShoppingListView
// - Uses @EnvironmentObject for ListViewModel data/context
// - Photo modal logic is handled locally in each row
// - Fully documented for learning and maintainability
//
// ------------------------------------------------------------------------

import SwiftUI

/// Wrapper for modal photo presentation, ensures unique identity per image tap.
struct ModalPhoto: Identifiable, Equatable {
    let id = UUID()
    let image: UIImage?
}
/// Represents a single row in the list view, displaying details of an item.
struct ListRowView: View {
    
    // MARK: - Properties
    
    /// The item model that this row represents.
    let item: ItemModel
    
    @State private var modalPhoto: ModalPhoto?
    
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
                    // Tap on the image opens it in fullscreen modal
                    .onTapGesture {
                        modalPhoto = ModalPhoto(image: uiImage)
                    }
            } else {
                Image("defaultImage")
                    .resizable()
                    .scaledToFit()
                    // Even if no custom image, allow tap to present modal with placeholder
                    .onTapGesture {
                        modalPhoto = ModalPhoto(image: nil)
                    }
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
            .strikethrough(item.isChecked, color: item.isChecked ? Color.theme.buttonIconColor : .none)
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
        // Presents the fullscreen product image modal if a product photo is set
        .sheet(item: $modalPhoto) { modal in
            ProductImageFullscreenView(
                image: modal.image ?? UIImage(named: "defaultImage")!,
                name: item.name,
                productDescription: item.productDescription,
                brand: item.brand
            )
            .presentationDetents([.fraction(0.5)])
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
