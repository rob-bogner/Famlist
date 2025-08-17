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

struct ItemThumbnail: View {
    let base64: String?
    let onTap: (UIImage?) -> Void
    var body: some View {
        let image = ImageCache.shared.image(fromBase64: base64)
        Group {
            if let image = image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Image("defaultImage").resizable().scaledToFit()
            }
        }
        .roundedCorners(5)
        .padding(10)
        .frame(width: 50, height: 50)
        .onTapGesture { onTap(image) }
    }
}

struct ItemTitle: View {
    let text: String
    let checked: Bool
    var body: some View {
        Text(text)
            .font(.headline)
            .strikethrough(checked, color: checked ? Color.theme.buttonIconColor : .clear)
            .frame(alignment: .leading)
    }
}

struct ItemMeta: View {
    let units: Int
    let measure: String
    let price: Double
    var body: some View {
        let displayMeasure = measure.isEmpty ? "" : Measure.fromExternal(measure).displayName
        HStack {
            Text(displayMeasure.isEmpty ? "\(units)" : "\(units) \(displayMeasure)")
            Spacer()
            Text(Formatting.priceText(price))
        }
        .font(.subheadline)
    }
}
/// Represents a single row in the list view, displaying details of an item.
struct ListRowView: View {
    
    // MARK: - Properties
    
    /// The item model that this row represents.
    let item: ItemModel
    
    @State private var modalPhoto: ModalPhoto?
    
    // MARK: - Computed Views
    
    
    // MARK: - Body
    
    /// The main body view of the row, composing image, name, and details with styling.
    var body: some View {
        ZStack {
            Color.theme.background
                .ignoresSafeArea()

            HStack(alignment: .top) {
                ItemThumbnail(base64: item.imageData) { tapped in
                    modalPhoto = ModalPhoto(image: tapped)
                }

                VStack(alignment: .leading) {
                    ItemTitle(text: item.name, checked: item.isChecked)
                    Spacer()
                    ItemMeta(units: item.units, measure: item.measure, price: item.price)
                }
                .padding(.trailing, 7)
                .padding(.vertical, 7)
            }
            .background(item.isChecked ? Color.theme.buttonFillColor : Color.clear)
            .cardStyle()
            .opacity(item.isChecked ? 0.5 : 1)
        }
        // Presents the fullscreen product image modal if a product photo is set
        .sheet(item: $modalPhoto) { modal in
            ProductImageFullscreenView(
                image: modal.image ?? UIImage(named: "defaultImage")!,
                name: item.name,
                productDescription: item.productDescription,
                brand: item.brand
            )
            .presentationDetents([.fraction(0.5), .medium])
            .presentationCornerRadius(15) // Smooth rounded sheet corners
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
