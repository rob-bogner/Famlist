/*
 ProductImageFullscreenView.swift

 Famlist
 Created on: 15.06.2025
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Presents a fullscreen modal to display a product photo along with optional name, description, and brand.

 🛠 Includes:
 - Black-themed background, close button via CustomModalView header, and tap-to-dismiss behavior.

 🔰 Notes for Beginners:
 - Designed to be presented from a sheet. If the passed image is tiny/placeholder, we fall back to a default asset.
 - Uses dependency-free UI; no network calls here.

 📝 Last Change:
 - Standardized header and preview switched to use PreviewMocks for consistent data.
 ------------------------------------------------------------------------
 */

import SwiftUI // Imports SwiftUI to build the fullscreen image view and use modifiers.

/// Presents a fullscreen modal with a product photo.
/// If image is empty, uses "defaultImage" asset as fallback.
struct ProductImageFullscreenView: View { // Declares a SwiftUI View for fullscreen photo display.
    /// The image to display fullscreen (required, can be fallback)
    let image: UIImage // Input image provided by caller.
    /// Optional product name to show beneath the image
    let name: String // Product name text.
    /// Optional long description of the product
    let productDescription: String? // Product description text.
    /// Optional brand label
    let brand: String? // Product brand text.

    /// Environment variable to dismiss the modal sheet
    @Environment(\.dismiss) private var dismiss // Allows closing this sheet when tapping anywhere.

    /// Returns a valid image: uses the provided image if non-empty, else fallback to defaultImage asset
    private var displayedImage: UIImage { // Picks the image to render.
        // If the image's size is zero or it's a system placeholder, fallback
        if image.size.width < 2 || image.size.height < 2 { // Very small images likely indicate placeholders.
            return UIImage(named: "defaultImage") ?? UIImage() // Use app asset or an empty UIImage.
        }
        return image // Use the provided image.
    }

    var body: some View { // Defines the modal layout and behavior.
        CustomModalView(title: String(localized: "productImage.title"), onClose: { dismiss() }) { // Modal with title and a close button.
            VStack(spacing: 12) { // Stack image and details with spacing.
                Spacer() // Push content towards vertical center.
                // The main product image, fit to screen and scaled
                Image(uiImage: displayedImage) // Convert UIImage into a SwiftUI Image for rendering.
                    .resizable() // Allow resizing to fit available space.
                    .cornerRadius(24) // Soften edges for a card-like feel.
                    .aspectRatio(contentMode: .fit) // Keep aspect ratio; fit within bounds.
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Expand to use available space.
                    .background(Color.theme.card) // Card-like background color behind the image.
                    .transition(.opacity.combined(with: .scale)) // Smooth fade/scale when appearing.
                // Product info below the image
                VStack(spacing: 4) { // Secondary info stacked beneath the image.
                    Text(name) // Product name text.
                        .font(.title2).fontWeight(.semibold) // Prominent weight for the name.
                        .foregroundColor(Color.theme.textColor) // Use theme text color for contrast.
                    if let desc = productDescription, !desc.isEmpty { // Only render description when present.
                        Text(desc) // Description text content.
                            .font(.body) // Standard body font.
                            .foregroundColor(Color.theme.textColor.opacity(0.85)) // Slightly dimmed text color.
                    }
                    if let brand = brand, !brand.isEmpty { // Render brand when provided.
                        Text(brand) // Brand label.
                            .font(.subheadline) // Smaller secondary font.
                            .foregroundColor(Color.theme.textColor.opacity(0.7)) // More dimmed for hierarchy.
                    }
                }
                .padding(.bottom, 32) // Space from bottom to avoid touching edges.
            }
            .background(Color.theme.card.ignoresSafeArea()) // Card background fills behind content and ignores safe areas.
            .contentShape(Rectangle()) // Makes the whole area tappable for dismissal.
            .onTapGesture { // Tapping anywhere dismisses the modal.
                dismiss() // Close the sheet.
            }
        }
    }
}

#Preview { // Preview block for the fullscreen product image view.
    // Pulls a sample item from PreviewMocks and uses its fields for a realistic preview.
    let item = PreviewMocks.sampleItems.first! // Use the first sample item.
    return ProductImageFullscreenView( // Construct the preview view with sample values.
        image: UIImage(named: "defaultImage")!, // Use the default asset for preview.
        name: item.name, // Preview name.
        productDescription: item.productDescription, // Preview description.
        brand: item.brand // Preview brand.
    )
    .environmentObject(PreviewMocks.makeListViewModelWithSamples()) // Inject preview ListViewModel for consistency.
}
