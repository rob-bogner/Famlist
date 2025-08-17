// MARK: - ReusableInputs.swift

/*
 File: ReusableInputs.swift
 Project: GroceryGenius
 Created: 20.07.2025
 Last Updated: 17.08.2025

 Overview:
 Reusable input building blocks (photo picker field, quantity+measure row, wheel picker, localized price input) used across add/edit item flows.

 Responsibilities / Includes:
 - PhotoField: image capture / selection (camera or library) + removal confirmation
 - QuantityMeasureRow: numeric units input with clamped stepper + measure selection sheet
 - MeasureWheelPicker: wheel-style measure selection (sheet detent)
 - PriceField: locale-aware decimal input normalizing to dot-decimal internal model
 - Utility haptic feedback (light impact)

 Design Notes:
 - Keeps internal numeric state as String to reduce formatter churn & allow partial user input
 - Wheel picker sheet uses internalSelection bridging to external String binding
 - PriceField avoids NumberFormatter mid-edit to prevent cursor jumps; manual filtering instead
 - Haptic feedback only on increment/decrement & remove to avoid over-stimulation

 Possible Enhancements:
 - Accessibility: VoiceOver custom rotor for measure selection
 - Input masking for thousands separators
 - Async image compression / orientation normalization before Base64 encoding
*/

import SwiftUI
import UIKit

// MARK: - Haptics
private func lightHaptic() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }

// MARK: - PhotoField
struct PhotoField: View {
    @Binding var image: UIImage?
    @State private var isPicker = false
    @State private var showSource = false
    @State private var source: UIImagePickerController.SourceType = .photoLibrary
    @State private var showRemoveConfirm = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let img = image {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipped()
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onTapGesture { showSource = true }
                        .accessibilityLabel(String(localized: "photo.add"))
                        .accessibilityAddTraits(.isButton)
                } else {
                    Button { showSource = true; lightHaptic() } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "camera")
                                .resizable().scaledToFit()
                                .frame(width: 32, height: 32)
                                .foregroundColor(.gray)
                            Text(String(localized: "photo.add"))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(width: 120, height: 120)
                    }
                    .accessibilityLabel(String(localized: "photo.add"))
                }
            }
            .background(Color.theme.card.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.35), lineWidth: 1)
            )

            if image != nil {
                Button {
                    lightHaptic()
                    showRemoveConfirm = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Circle().fill(Color.black.opacity(0.55)))
                        .padding(4)
                }
                .accessibilityLabel(String(localized: "photo.remove.action"))
                .confirmationDialog(String(localized: "photo.remove.confirmTitle"), isPresented: $showRemoveConfirm, titleVisibility: .visible) {
                    Button(String(localized: "photo.remove.action"), role: .destructive) { image = nil }
                    Button(String(localized: "photo.cancel"), role: .cancel) {}
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog(String(localized: "photo.selectSource.title"), isPresented: $showSource, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button(String(localized: "photo.take")) { source = .camera; isPicker = true }
            }
            Button(String(localized: "photo.choose")) { source = .photoLibrary; isPicker = true }
            if image != nil { Button(String(localized: "photo.removeCurrent.action"), role: .destructive) { image = nil } }
            Button(String(localized: "photo.cancel"), role: .cancel) {}
        }
        .sheet(isPresented: $isPicker) { ImagePicker(selectedImage: $image, isPresented: $isPicker, sourceType: source) }
    }
}

// MARK: - Quantity + Measure Row
struct QuantityMeasureRow: View {
    @Binding var units: String
    @Binding var measure: String
    var range: ClosedRange<Int> = 1...999

    private var value: Int { Int(units) ?? range.lowerBound }
    private var atMin: Bool { value <= range.lowerBound }
    private var atMax: Bool { value >= range.upperBound }
    private let controlHeight: CGFloat = 34
    private let measureMinWidth: CGFloat = 120
    @State private var showMeasurePicker = false

    var body: some View {
        HStack(spacing: 12) {
            TextField(String(localized: "field.units.placeholder"), text: $units)
                .keyboardType(.numberPad)
                .frame(width: 70, height: controlHeight)
                .multilineTextAlignment(.leading)
                .textFieldStyle(.roundedBorder)
                .onChange(of: units) { _, newValue in
                    let digits = newValue.filter { $0.isNumber }
                    let intVal = Int(digits) ?? range.lowerBound
                    let clamped = min(max(intVal, range.lowerBound), range.upperBound)
                    let normalized = String(clamped)
                    if normalized != units { units = normalized }
                }
            Button { showMeasurePicker = true } label: {
                HStack {
                    let current = Measure.fromExternal(measure)
                    Text(measure.isEmpty ? String(localized: "measure.placeholder") : current.localizedName)
                        .foregroundColor(measure.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
                .padding(.horizontal, 10)
                .frame(minWidth: measureMinWidth, maxWidth: .infinity, minHeight: controlHeight, maxHeight: controlHeight, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.35)))
            }
            .layoutPriority(1)
            .accessibilityLabel(String(localized: "measure.placeholder"))
            .sheet(isPresented: $showMeasurePicker) {
                MeasureWheelPicker(selection: $measure)
                    .presentationDetents([.fraction(0.35)])
            }
            HStack(spacing: 12) {
                Button { decrement() } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: controlHeight, height: controlHeight)
                        .background(Capsule().fill(atMin ? Color.gray.opacity(0.35) : Color.accentColor))
                }.disabled(atMin).accessibilityLabel("decrement")
                Button { increment() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: controlHeight, height: controlHeight)
                        .background(Capsule().fill(atMax ? Color.gray.opacity(0.35) : Color.accentColor))
                }.disabled(atMax).accessibilityLabel("increment")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func decrement() { var v = value; if v > range.lowerBound { v -= 1; units = String(v); lightHaptic() } }
    private func increment() { var v = value; if v < range.upperBound { v += 1; units = String(v); lightHaptic() } }
}

// MARK: - Wheel Picker Sheet
private struct MeasureWheelPicker: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    private var measures: [Measure] { Measure.allCases }
    @State private var internalSelection: Measure = .piece

    var body: some View {
        VStack(spacing: 12) {
            HStack { Spacer(); Button(String(localized: "button.done")) { selection = internalSelection.rawValue; dismiss() }.bold() }
                .padding(.horizontal)
            Picker("Measure", selection: $internalSelection) {
                ForEach(measures, id: \.self) { m in Text(m.localizedName).tag(m) }
            }
            .pickerStyle(.wheel)
            .onAppear { internalSelection = Measure.fromExternal(selection) }
        }
        .presentationDragIndicator(.visible)
    }
}

// MARK: - PriceField (Locale-Aware Decimal Input)
struct PriceField: View {
    @Binding var price: String
    var showCurrencySymbol: Bool = true
    var errorMessage: String? = nil
    @State private var internalText: String = ""
    @State private var suppressExternalSync = false
    @State private var lastSyncedRawPrice: String = ""
    private var locale: Locale { .current }
    private var decimalSeparator: String { locale.decimalSeparator ?? "." }
    private var allowedChars: Set<Character> { Set("0123456789" + decimalSeparator) }
    private let fieldWidth: CGFloat = 70

    var body: some View {
        HStack(spacing: 6) {
            TextField(String(localized: "field.price.placeholder"), text: Binding(
                get: { internalText.isEmpty ? displayStringFromStoredPrice() : internalText },
                set: { newVal in
                    suppressExternalSync = true
                    let filtered = newVal.filter { allowedChars.contains($0) }
                    var result = ""
                    var separatorUsed = false
                    for ch in filtered {
                        if ch == Character(decimalSeparator) { if separatorUsed { continue }; separatorUsed = true }
                        result.append(ch)
                    }
                    internalText = result
                    price = result.replacingOccurrences(of: decimalSeparator, with: ".")
                    lastSyncedRawPrice = price
                    DispatchQueue.main.async { suppressExternalSync = false }
                }
            ))
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
            .frame(width: fieldWidth, height: 44)
            .multilineTextAlignment(.leading)
            .lineLimit(1)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(errorMessage == nil ? Color.clear : Color.red.opacity(0.8), lineWidth: 1)
            )
            .accessibilityLabel(String(localized: "field.price.placeholder"))
            if showCurrencySymbol {
                Text(locale.currencySymbol ?? "€")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                    .frame(height: 44)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { syncFromBindingIfNeeded(force: true) }
        .onChange(of: price) { _, _ in syncFromBindingIfNeeded(force: false) }
    }

    private func displayStringFromStoredPrice() -> String {
        let normalized = price.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else { return price.replacingOccurrences(of: ".", with: decimalSeparator) }
        var raw = String(value)
        if raw.hasSuffix(".0") { raw.removeLast(2) }
        return raw.replacingOccurrences(of: ".", with: decimalSeparator)
    }
    private func syncFromBindingIfNeeded(force: Bool) {
        guard !suppressExternalSync else { return }
        let currentRaw = price
        if force || currentRaw != lastSyncedRawPrice {
            internalText = displayStringFromStoredPrice()
            lastSyncedRawPrice = currentRaw
        }
    }
}
