//
//  ProductImageFullscreenView.swift
//  GroceryGenius
//
// GroceryGenius
// ProductImageFullscreenView.swift
// Created on: 15.06.2025
// Last updated on: 15.06.2025
//
// ------------------------------------------------------------------------
// 📄 File Overview:
//
// This view presents a fullscreen modal for displaying a product photo (UIImage).
// Always uses a black background for optimal image contrast and clarity.
// If the provided image is empty, the default asset "defaultImage" is shown as fallback.
//
// 🖌️ Modern UI Features:
// - Fullscreen photo display with black background for best viewing
// - Always-visible close (X) button in the top-right
// - Tap anywhere to dismiss the modal
// - Automatic fallback to the default image asset if image is empty
//
// 🧑‍💻 Developer Notes:
// - Designed for modal presentation via .sheet in ListRowView
// - Robust to nil or empty UIImage input
// - All logic is super-documented for learning and maintainability
//
// ------------------------------------------------------------------------

import SwiftUI

/// Presents a fullscreen modal with a product photo.
/// If image is empty, uses "defaultImage" asset as fallback.
struct ProductImageFullscreenView: View {
    /// The image to display fullscreen (required, can be fallback)
    let image: UIImage
    let name: String
    let productDescription: String?
    let brand: String?

    /// Environment variable to dismiss the modal sheet
    @Environment(\.dismiss) private var dismiss

    /// Returns a valid image: uses the provided image if non-empty, else fallback to defaultImage asset
    private var displayedImage: UIImage {
        // If the image's size is zero or it's a system placeholder, fallback
        if image.size.width < 2 || image.size.height < 2 {
            return UIImage(named: "defaultImage") ?? UIImage()
        }
        return image
    }

    var body: some View {
        ZStack {
            Color.theme.card
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                HStack {
                    Spacer(minLength: 0)
                    Text("Product Image")
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
                .padding(.top, 25)
                Spacer()
                // The main product image, fit to screen and scaled
                Image(uiImage: displayedImage)
                    .resizable()
                    .cornerRadius(24)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.theme.card)
                    .transition(.opacity.combined(with: .scale))
                // Produktinfos unter dem Bild
                VStack(spacing: 4) {
                    Text(name)
                        .font(.title2).fontWeight(.semibold)
                        .foregroundColor(Color.theme.textColor)
                    if let desc = productDescription, !desc.isEmpty {
                        Text(desc)
                            .font(.body)
                            .foregroundColor(Color.theme.textColor.opacity(0.85))
                    }
                    if let brand = brand, !brand.isEmpty {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundColor(Color.theme.textColor.opacity(0.7))
                    }
                }
                .padding(.bottom, 32)
            }
        }
        // Also allow tap anywhere to dismiss
        .contentShape(Rectangle())
        .onTapGesture {
            dismiss()
        }
    }
}

#Preview {
    ProductImageFullscreenView(
        image: UIImage(systemName: "photo")!,
        name: "Milch",
        productDescription: "Haltbare Milch 3,5%",
        brand: "Demeter"
    )
}
