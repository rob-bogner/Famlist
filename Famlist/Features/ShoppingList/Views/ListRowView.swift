/*
 ListRowView.swift

 Famlist
 Created on: 27.11.2023
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Row representation of a single shopping list item with image, title, and meta (units + measure + price) and optional strike-through when checked.

 🛠 Includes:
 - Base64 image decode via ImageCache, placeholder fallback, fullscreen image sheet, and visual differentiation for checked state.

 🔰 Notes for Beginners:
 - The row composes small subviews (thumbnail, title, meta) for readability and reuse.
 - Tapping the image opens a fullscreen preview; swipe actions live in ListView, not here.

 📝 Last Change:
 - Standardized header and updated Preview to use PreviewMocks for consistent sample data. No functional changes.
 ------------------------------------------------------------------------
 */

import SwiftUI // Imports SwiftUI to compose the row UI and present sheets.

/// Wrapper for modal photo presentation, ensures unique identity per image tap.
struct ModalPhoto: Identifiable, Equatable { // Identifiable so .sheet(item:) can present/dismiss.
    let id = UUID() // Unique id per modal instance.
    let image: UIImage? // The tapped image (if available) to present fullscreen.
}

/// Thumbnail renderer that decides between remote URL, base64, or default placeholder.
struct ItemThumbnail: View { // Reusable thumbnail component for a list row.
    let imageUrl: String? // Optional remote URL string.
    let base64: String? // Optional base64 image payload.
    let onTap: (UIImage?) -> Void // Callback when the thumbnail is tapped (passes UIImage if available).
    @State private var loadedRemoteImage: UIImage? = nil // Cache a fetched remote UIImage for fullscreen display.

    var body: some View { // Compose the thumbnail content.
        let url = imageUrl.flatMap(URL.init(string:)) // Convert string to URL if possible.
        Group { // Choose source at runtime.
            if let url { // Remote image path provided.
                AsyncImage(url: url) { phase in // SwiftUI async image loader.
                    switch phase { // Handle loading states.
                    case .empty:
                        Image("defaultImage").resizable().scaledToFit() // Placeholder while loading.
                    case .success(let image):
                        image.resizable().scaledToFit() // Render the fetched image.
                            .onAppear { loadRemoteUIImage(from: url) } // Also fetch raw data for fullscreen modal.
                    case .failure:
                        Image("defaultImage").resizable().scaledToFit() // Fallback on error.
                    @unknown default:
                        Image("defaultImage").resizable().scaledToFit() // Future-proof fallback.
                    }
                }
            } else if let img = ImageCache.shared.image(fromBase64: base64) { // Decode base64 when URL not present.
                Image(uiImage: img).resizable().scaledToFit() // Render decoded image.
            } else { // No URL and no base64 => default asset.
                Image("defaultImage").resizable().scaledToFit() // Default placeholder image.
            }
        }
        .roundedCorners(10) // Slightly rounded edges.
        .padding(.horizontal, 10) // Breathing room left/right of thumbnail.
        .frame(width: 80, height: 80) // Larger size for better visibility and touch target.
        .onTapGesture { onTap(loadedImageForTap(hasRemoteURL: url != nil)) } // Emit the best UIImage we have to open fullscreen.
    }

    /// Chooses the UIImage to provide to the tap handler.
    private func loadedImageForTap(hasRemoteURL: Bool) -> UIImage? { // Prefer remote image when available.
        if hasRemoteURL { return loadedRemoteImage } // Remote image already fetched as UIImage.
        return ImageCache.shared.image(fromBase64: base64) // Else decode base64 again (cheap with cache).
    }

    /// Fetches the remote image data once to enable fullscreen display.
    private func loadRemoteUIImage(from url: URL) { // Avoids refetching on every tap.
        // Fetch once to enable fullscreen modal with UIImage
        guard loadedRemoteImage == nil else { return } // Skip if we already have it.
        Task { // Perform async fetch on a background task.
            if let (data, _) = try? await URLSession.shared.data(from: url), let ui = UIImage(data: data) { // Download and decode.
                loadedRemoteImage = ui // Cache for tap handler.
            }
        }
    }
}

/// Title text with optional strike-through when the item is checked.
struct ItemTitle: View { // Simple text styling component.
    let text: String // Item name.
    let checked: Bool // Whether the item is marked as checked.
    var body: some View { // Render the title.
        Text(text) // The item name.
            .font(.headline) // Prominent headline font.
            .strikethrough(checked, color: checked ? Color.theme.buttonIconColor : .clear) // Strike-through when checked.
            .frame(maxWidth: .infinity, alignment: .leading) // Full width, aligned to leading.
    }
}

/// Brand/product description line displayed below the title.
struct ItemBrand: View { // Secondary product information component.
    let brand: String // Brand name.
    var body: some View { // Render the brand.
        Text(brand) // The brand name.
            .font(.subheadline) // Smaller font than title.
            .foregroundColor(.secondary) // Subtle color for less emphasis.
            .frame(maxWidth: .infinity, alignment: .leading) // Full width, aligned to leading.
    }
}

/// Meta row with units/measure and price.
struct ItemMeta: View { // Secondary information about the item.
    let units: Int // Quantity.
    let measure: String // Measure token as stored in model.
    let price: Double // Price per unit.
    var body: some View { // Compose meta content.
        let displayMeasure = measure.isEmpty ? "" : Measure.fromExternal(measure).localizedName // Localize measure when present.
        HStack { // Layout: units+measure left, price right (if present).
            Text(displayMeasure.isEmpty ? "\(units)" : "\(units) \(displayMeasure)") // Display either only units or units + measure.
            
            if price > 0 { // Only show price if it's greater than zero.
                Spacer() // Push price to trailing edge.
                Text(Formatting.priceText(price)) // Localized currency rendering.
            }
        }
        .font(.subheadline) // Subtle font for meta info.
    }
}

/// Represents a single row in the list view, displaying details of an item.
struct ListRowView: View { // Main row view combining thumbnail, title, and meta.

    // MARK: - Properties

    /// The item model that this row represents.
    let item: ItemModel // Data to render.

    /// Called when the user confirms a manual retry for a failed sync.
    var onRetry: (() -> Void)?

    @State private var modalPhoto: ModalPhoto? // Triggers .sheet presentation when set.
    @State private var showRetryConfirmation = false // Controls the retry confirmation dialog.
    
    // MARK: - Body
    
    /// The main body view of the row, composing image, name, and details with styling.
    var body: some View { // Build the row layout.
        ZStack { // Background layering for card look.
            Color.theme.background // Card background color to match list.
                .ignoresSafeArea() // Extend background color to edges.

            HStack(alignment: .center, spacing: DS.Spacing.xs) { // Horizontal layout with vertically centered thumbnail, reduced spacing for tighter layout.
                ItemThumbnail(imageUrl: item.imageUrl, base64: item.imageData) { tapped in // Thumbnail with tap callback.
                    modalPhoto = ModalPhoto(image: tapped) // Prepare modal data with the tapped image.
                }

                VStack(alignment: .leading, spacing: 0) { // Text column with custom spacing between elements.
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) { // Title and brand grouped together with tight spacing (4pt).
                        ItemTitle(text: item.name, checked: item.isChecked) // Title with strike-through when checked.

                        if let brand = item.brand, !brand.isEmpty { // Only show brand if present.
                            ItemBrand(brand: brand) // Brand line below title.
                        } else {
                            Text(" ") // Invisible placeholder to maintain consistent row height when brand is missing.
                                .font(.subheadline) // Same size as ItemBrand.
                                .frame(maxWidth: .infinity, alignment: .leading) // Match ItemBrand frame.
                        }
                    }

                    Spacer() // Push meta to bottom, creating larger gap between brand and meta.

                    ItemMeta(units: item.units, measure: item.measure, price: item.price) // Units/measure/price line at bottom.
                }
                .padding(.vertical, 8) // Small padding at top and bottom for breathing room from card edges.
                .frame(minHeight: 70) // Minimum height ensures consistent rows, padding adds to this.
                .padding(.trailing, 10) // Space from right edge to avoid clipping.

                if item.isSyncFailed { // Warn icon when sync permanently failed.
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .padding(.trailing, 12)
                        .onTapGesture { showRetryConfirmation = true }
                        .accessibilityLabel("Sync fehlgeschlagen. Tippen zum erneuten Synchronisieren.")
                }
            }
            .background(item.isChecked ? Color.theme.buttonFillColor : Color.clear) // Tint background when checked.
            .cardStyle() // Rounded card styling from DesignSystem.
            .springCheckAnimation(isChecked: item.isChecked) // Spring animation for check/uncheck
            .confirmationDialog(
                "Sync fehlgeschlagen",
                isPresented: $showRetryConfirmation,
                titleVisibility: .visible
            ) {
                Button("Erneut synchronisieren") { onRetry?() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Der Artikel konnte nicht synchronisiert werden. Soll ein neuer Versuch gestartet werden?")
            }
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)).combined(with: .scale(scale: 0.95)),
            removal: .opacity.combined(with: .scale(scale: 0.8))
        )) // Slide-in from trailing when added, fade-out with scale when removed
        // Presents the fullscreen product image modal if a product photo is set
        .sheet(item: $modalPhoto) { modal in // Present when modalPhoto is non-nil.
            ProductImageFullscreenView(
                image: modal.image ?? UIImage(named: "defaultImage")!, // Fallback to default asset.
                name: item.name, // Pass item name.
                productDescription: item.productDescription, // Optional description.
                brand: item.brand // Optional brand.
            )
            .presentationDetents([.fraction(0.5), .medium]) // Allow half and medium heights.
            .presentationCornerRadius(15) // Smooth rounded sheet corners
            .presentationDragIndicator(.visible) // Show drag indicator
            .transition(.scale.combined(with: .opacity)) // Smooth zoom transition for image
        }
    }
}

#Preview { // Preview for the row component with a sample item.
    // Preview uses a sample item from PreviewMocks to keep data consistent across previews
    ListRowView(item: PreviewMocks.sampleItems.first!) // Render a single row using a sample item.
}
