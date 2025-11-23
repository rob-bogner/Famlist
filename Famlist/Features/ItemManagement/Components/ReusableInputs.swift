/*
 ReusableInputs.swift

 Famlist
 Created on: 20.07.2025
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Reusable input building blocks (photo picker field, quantity+measure row, wheel picker, localized price input) used across add/edit item flows.

 🛠 Includes:
 - PhotoField: image capture/selection (camera or library) + removal confirmation
 - QuantityMeasureRow: numeric units input with clamped stepper + measure selection sheet
 - MeasureWheelPicker: wheel-style measure selection (sheet detent)
 - PriceField: locale-aware decimal input normalizing to dot-decimal internal model
 - Utility haptic feedback (light impact)

 🔰 Notes for Beginners:
 - Keeps internal numeric state as String to reduce formatter churn & allow partial user input
 - Wheel picker sheet uses internalSelection bridging to external String binding
 - PriceField avoids NumberFormatter mid-edit to prevent cursor jumps; manual filtering instead
 - Haptic feedback only on increment/decrement & remove to avoid over-stimulation

 📝 Last Change:
 - Standardized header, added concise comments, and appended a preview that uses PreviewMocks.
 ------------------------------------------------------------------------
 */

import SwiftUI // SwiftUI for Views, modifiers, bindings, and previews.
import UIKit // UIKit for UIImage and UIImagePickerController.SourceType.

// MARK: - Haptics
private func lightHaptic() { UIImpactFeedbackGenerator(style: .light).impactOccurred() } // One-tap light impact feedback.

// MARK: - PhotoField
/// A square photo input showing either a selected image or a button to add one.
struct PhotoField: View { // Reusable control for picking/removing a photo.
    @Binding var image: UIImage? // Two-way binding to an optional image selected by the user.
    @State private var isPicker = false // Controls presentation of the system image picker sheet.
    @State private var showSource = false // Controls the confirmation dialog to pick the source (camera/library).
    @State private var source: UIImagePickerController.SourceType = .photoLibrary // Selected source type default.
    @State private var showRemoveConfirm = false // Controls the dialog to confirm removing the current photo.

    var body: some View { // Assembles the photo UI.
        ZStack(alignment: .topTrailing) { // Overlay a tiny remove button at top-right when image exists.
            Group { // Switch between existing image and add button.
                if let img = image { // When an image is set, display it.
                    Image(uiImage: img)
                        .resizable().scaledToFill() // Fill the square while preserving aspect ratio.
                        .frame(width: 120, height: 120) // Fixed size for consistency.
                        .clipped() // Clip overflow outside the frame.
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous)) // Tap shape.
                        .onTapGesture { showSource = true } // Tapping the image re-opens source picker.
                        .accessibilityLabel(String(localized: "photo.add")) // Spoken label for VoiceOver.
                        .accessibilityAddTraits(.isButton) // Mark as button for accessibility.
                } else { // Show an add button when there’s no image yet.
                    Button { showSource = true; lightHaptic() } label: { // Present source dialog and haptic.
                        VStack(spacing: 8) { // Icon + text stacked.
                            Image(systemName: "camera") // Camera icon.
                                .resizable().scaledToFit() // Fit within its frame.
                                .frame(width: 32, height: 32) // Icon size.
                                .foregroundColor(.gray) // Subtle tint.
                            Text(String(localized: "photo.add")) // Localized label below.
                                .font(.caption) // Small text.
                                .foregroundColor(.gray) // Subtle color.
                        }
                        .frame(width: 120, height: 120) // Same square size as a selected image.
                    }
                    .accessibilityLabel(String(localized: "photo.add")) // VoiceOver label for the add button.
                    .buttonStyle(.plain) // Prevent iOS 26 from adding tinted borders to our custom-styled tile.
                }
            }
            .background(Color.theme.card.opacity(0.4)) // Slight tinted background for visibility.
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)) // Rounded corners around the square.
            .overlay( // Thin border outline.
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.35), lineWidth: 1) // Soft gray stroke.
            )

            if image != nil { // Show remove button only when there’s an image.
                Button { // Tapping triggers confirmation.
                    lightHaptic() // Give feedback.
                    showRemoveConfirm = true // Show dialog.
                } label: {
                    Image(systemName: "xmark") // X icon.
                        .font(.system(size: 10, weight: .bold)) // Small bold icon.
                        .foregroundColor(.white) // White on dark.
                        .padding(6) // Padding for touch area.
                        .background(Circle().fill(Color.black.opacity(0.55))) // Dark circular background.
                        .padding(4) // Spacing from the edges.
                }
                .buttonStyle(.plain) // Keep the floating close pill borderless across iOS versions.
                .accessibilityLabel(String(localized: "photo.remove.action")) // A11y label.
                .confirmationDialog(String(localized: "photo.remove.confirmTitle"), isPresented: $showRemoveConfirm, titleVisibility: .visible) { // Confirm removal.
                    Button(String(localized: "photo.remove.action"), role: .destructive) { image = nil } // Remove photo.
                    Button(String(localized: "photo.cancel"), role: .cancel) {} // Cancel.
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // Align to leading within container.
        .confirmationDialog(String(localized: "photo.selectSource.title"), isPresented: $showSource, titleVisibility: .visible) { // Pick source.
            if UIImagePickerController.isSourceTypeAvailable(.camera) { // Offer camera only if device supports it.
                Button(String(localized: "photo.take")) { source = .camera; isPicker = true } // Choose camera.
            }
            Button(String(localized: "photo.choose")) { source = .photoLibrary; isPicker = true } // Choose library.
            if image != nil { Button(String(localized: "photo.removeCurrent.action"), role: .destructive) { image = nil } } // Quick remove option.
            Button(String(localized: "photo.cancel"), role: .cancel) {} // Cancel.
        }
        .sheet(isPresented: $isPicker) { ImagePicker(selectedImage: $image, isPresented: $isPicker, sourceType: source) } // Present image picker.
    }
}

// MARK: - Quantity + Measure Row
/// A compact row with a numeric units field, a measure picker button, and +/- stepper buttons.
struct QuantityMeasureRow: View { // Lets users set a quantity and pick a unit.
    @Binding var units: String // Two-way string binding for units (keeps partial input possible).
    @Binding var measure: String // Two-way binding to the selected measure stored as String.
    var range: ClosedRange<Int> = 1...999 // Allowed range for units.

    private var value: Int { Int(units) ?? range.lowerBound } // Current integer value clamped by parsing.
    private var atMin: Bool { value <= range.lowerBound } // Whether value is at lower bound.
    private var atMax: Bool { value >= range.upperBound } // Whether value is at upper bound.
    private let controlHeight: CGFloat = 34 // Common height for controls.
    private let measureMinWidth: CGFloat = 120 // Minimum width for measure button.
    @State private var showMeasurePicker = false // Controls sheet presentation for the wheel picker.

    var body: some View { // Build the row.
        HStack(spacing: 12) { // Arrange the three segments with spacing.
            TextField(String(localized: "field.units.placeholder"), text: $units) // Numeric text field for units.
                .keyboardType(.numberPad) // Number pad keyboard.
                .frame(width: 70, height: controlHeight) // Compact width to avoid hogging space.
                .multilineTextAlignment(.leading) // Align text left.
                .textFieldStyle(.roundedBorder) // Rounded border style for clarity.
                .onChange(of: units) { _, newValue in // Sanitize input on each change.
                    let digits = newValue.filter { $0.isNumber } // Keep only digits.
                    let intVal = Int(digits) ?? range.lowerBound // Parse to int or fallback to min.
                    let clamped = min(max(intVal, range.lowerBound), range.upperBound) // Clamp within range.
                    let normalized = String(clamped) // Convert back to string.
                    if normalized != units { units = normalized } // Write back only if different.
                }
            Button { showMeasurePicker = true } label: { // Open measure picker sheet.
                HStack { // Label with current measure and chevrons.
                    let current = Measure.fromExternal(measure) // Normalize to enum.
                    Text(measure.isEmpty ? String(localized: "measure.placeholder") : current.localizedName) // Placeholder or localized name.
                        .foregroundColor(measure.isEmpty ? .secondary : .primary) // Dim placeholder.
                        .lineLimit(1) // Single-line label.
                        .minimumScaleFactor(0.8) // Scale down if needed.
                    Spacer(minLength: 4) // Small separation before icon.
                    Image(systemName: "chevron.up.chevron.down").font(.caption2) // Up/down icon.
                }
                .padding(.horizontal, 10) // Horizontal padding inside the button.
                .frame(minWidth: measureMinWidth, maxWidth: .infinity, minHeight: controlHeight, maxHeight: controlHeight, alignment: .leading) // Button sizing.
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.35))) // Subtle border.
            }
            .layoutPriority(1) // Give measure button priority to avoid truncation.
            .accessibilityLabel(String(localized: "measure.placeholder")) // VoiceOver label.
            .buttonStyle(.plain) // Avoid system-added outlines on the custom measure picker control.
            .sheet(isPresented: $showMeasurePicker) { // Wheel picker sheet.
                MeasureWheelPicker(selection: $measure)
                    .presentationDetents([.fraction(0.35)]) // Compact height.
            }
            HStack(spacing: 12) { // Stepper-style +/- buttons.
                Button { decrement() } label: { // Decrease value.
                    Image(systemName: "minus") // Minus icon.
                        .font(.system(size: 20, weight: .semibold)) // Icon size.
                        .foregroundColor(.white) // White foreground.
                        .frame(width: controlHeight, height: controlHeight) // Square touch area.
                        .background(Capsule().fill(atMin ? Color.gray.opacity(0.35) : Color.accentColor)) // Gray when disabled.
                }.disabled(atMin).accessibilityLabel("decrement") // Disable at min.
                .buttonStyle(.plain) // Keep capsule buttons borderless under iOS 26.
                Button { increment() } label: { // Increase value.
                    Image(systemName: "plus") // Plus icon.
                        .font(.system(size: 20, weight: .semibold)) // Icon size.
                        .foregroundColor(.white) // White foreground.
                        .frame(width: controlHeight, height: controlHeight) // Square touch area.
                        .background(Capsule().fill(atMax ? Color.gray.opacity(0.35) : Color.accentColor)) // Gray when disabled.
                }.disabled(atMax).accessibilityLabel("increment") // Disable at max.
                .buttonStyle(.plain) // Remove default bordered style on increment button.
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // Expand horizontally.
    }
    private func decrement() { var v = value; if v > range.lowerBound { v -= 1; units = String(v); lightHaptic() } } // Decrease within range.
    private func increment() { var v = value; if v < range.upperBound { v += 1; units = String(v); lightHaptic() } } // Increase within range.
}

// MARK: - Wheel Picker Sheet
/// Compact wheel-style picker for selecting a measurement unit.
private struct MeasureWheelPicker: View { // Presented as a sheet.
    @Binding var selection: String // External string binding for measure.
    @Environment(\.dismiss) private var dismiss // Dismiss action for the sheet.
    private var measures: [Measure] { Measure.allCases } // All supported units.
    @State private var internalSelection: Measure = .piece // Internal enum state mapping to the string.

    var body: some View { // Compose the wheel and a Done button.
        VStack(spacing: 12) { // Vertical stack layout.
            HStack { Spacer(); Button(String(localized: "button.done")) { selection = internalSelection.rawValue; dismiss() }.bold() } // Done button aligns to trailing.
                .padding(.horizontal) // Side padding.
            Picker("Measure", selection: $internalSelection) { // Wheel picker of measures.
                ForEach(measures, id: \.self) { m in Text(m.localizedName).tag(m) } // Localized names.
            }
            .pickerStyle(.wheel) // iOS wheel style.
            .onAppear { internalSelection = Measure.fromExternal(selection) } // Sync initial selection.
        }
        .presentationDragIndicator(.visible) // Show pull indicator.
    }
}

// MARK: - PriceField (Locale-Aware Decimal Input)
/// Locale-aware price input that stores values in dot-decimal format under the hood.
struct PriceField: View { // Avoids NumberFormatter mid-edit to keep cursor stable.
    @Binding var price: String // External binding storing normalized dot-decimal string.
    var showCurrencySymbol: Bool = true // Whether to show the trailing currency symbol.
    var errorMessage: String? = nil // Optional error message for validation border.
    @State private var internalText: String = "" // What the user currently sees/edits.
    @State private var suppressExternalSync = false // Avoid feedback loops when updating binding.
    @State private var lastSyncedRawPrice: String = "" // Tracks last synced raw binding value.
    private var locale: Locale { .current } // Current device locale.
    private var decimalSeparator: String { locale.decimalSeparator ?? "." } // Locale decimal separator.
    private var allowedChars: Set<Character> { Set("0123456789" + decimalSeparator) } // Allowed characters in field.
    private let fieldWidth: CGFloat = 70 // Text field width.

    var body: some View { // Compose text field and symbol.
        HStack(spacing: 6) { // Horizontal layout for input and currency symbol.
            TextField(String(localized: "field.price.placeholder"), text: Binding( // Bind to internal text bridging to external price.
                get: { internalText.isEmpty ? displayStringFromStoredPrice() : internalText }, // Show formatted binding when internal empty.
                set: { newVal in // Filter and normalize on each change.
                    suppressExternalSync = true // Prevent onChange loop.
                    let filtered = newVal.filter { allowedChars.contains($0) } // Keep only digits+separator.
                    var result = "" // Build a string with at most one separator.
                    var separatorUsed = false // Track if we've inserted the separator already.
                    for ch in filtered { // Iterate characters.
                        if ch == Character(decimalSeparator) { if separatorUsed { continue }; separatorUsed = true } // Allow only one decimal separator.
                        result.append(ch) // Append character.
                    }
                    internalText = result // Update internal field.
                    price = result.replacingOccurrences(of: decimalSeparator, with: ".") // Normalize to dot-decimal for storage.
                    lastSyncedRawPrice = price // Record last sync.
                    DispatchQueue.main.async { suppressExternalSync = false } // Re-enable external sync next runloop.
                }
            ))
            .keyboardType(.decimalPad) // Numeric keypad with decimal.
            .textFieldStyle(.roundedBorder) // Rounded style.
            .frame(width: fieldWidth, height: 44) // Fixed size.
            .multilineTextAlignment(.leading) // Left-align content.
            .lineLimit(1) // Single line.
            .overlay( // Show red border when error.
                RoundedRectangle(cornerRadius: 8)
                    .stroke(errorMessage == nil ? Color.clear : Color.red.opacity(0.8), lineWidth: 1) // Conditional border.
            )
            .accessibilityLabel(String(localized: "field.price.placeholder")) // VoiceOver label.
            if showCurrencySymbol { // Optionally show currency.
                Text(locale.currencySymbol ?? "€") // Display symbol (fallback to €).
                    .font(.subheadline.weight(.semibold)) // Slightly bold.
                    .foregroundColor(.secondary) // Subtle color.
                    .frame(height: 44) // Align with field height.
                    .accessibilityHidden(true) // Decorative only.
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // Expand horizontally.
        .onAppear { syncFromBindingIfNeeded(force: true) } // Initialize internal text on appear.
        .onChange(of: price) { _, _ in syncFromBindingIfNeeded(force: false) } // Sync when external binding changes.
    }

    private func displayStringFromStoredPrice() -> String { // Turns normalized price into localized display text.
        let normalized = price.replacingOccurrences(of: ",", with: ".") // Ensure dot separator in stored string.
        guard let value = Double(normalized) else { return price.replacingOccurrences(of: ".", with: decimalSeparator) } // If not a number, just swap separator for display.
        var raw = String(value) // Convert to string without localization formatting.
        if raw.hasSuffix(".0") { raw.removeLast(2) } // Drop trailing ".0" for cleaner look.
        return raw.replacingOccurrences(of: ".", with: decimalSeparator) // Use locale separator.
    }
    private func syncFromBindingIfNeeded(force: Bool) { // Sync internal text from binding when needed.
        guard !suppressExternalSync else { return } // Skip if we’re mid-update.
        let currentRaw = price // Snapshot current binding value.
        if force || currentRaw != lastSyncedRawPrice { // Only update when forced or changed.
            internalText = displayStringFromStoredPrice() // Refresh internal text.
            lastSyncedRawPrice = currentRaw // Update tracker.
        }
    }
}

#Preview { // Preview for reusable inputs using in-memory view model from PreviewMocks.
    VStack(spacing: 20) { // Vertical stack of components with spacing.
        PhotoField(image: .constant(nil)) // Photo field showing the add state.
        QuantityMeasureRow(units: .constant("2"), measure: .constant("piece")) // Row prefilled with sample values.
        PriceField(price: .constant("1.99")) // Price input preview.
    }
    .padding() // Padding around the preview content.
    .environmentObject(PreviewMocks.makeListViewModelWithSamples()) // Provide sample environment.
}
