// ReusableInputs.swift
// Wiederverwendbare Eingabe-Bausteine
import SwiftUI
import UIKit

// MARK: - Haptics Helper
private func lightHaptic() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }

// MARK: Foto-Auswahl (Kamera / Galerie)
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
                        .accessibilityLabel("Produktfoto")
                        .accessibilityAddTraits(.isButton)
                } else {
                    Button { showSource = true; lightHaptic() } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "camera")
                                .resizable().scaledToFit()
                                .frame(width: 32, height: 32)
                                .foregroundColor(.gray)
                            Text("Add Photo")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(width: 120, height: 120)
                    }
                    .accessibilityLabel("Foto hinzufügen")
                }
            }
            .background(Color.theme.card.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.35), lineWidth: 1)
            )

            if image != nil {
                // Remove Button
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
                .accessibilityLabel("Foto entfernen")
                .confirmationDialog("Remove Photo?", isPresented: $showRemoveConfirm, titleVisibility: .visible) {
                    Button("Remove", role: .destructive) { image = nil }
                    Button("Cancel", role: .cancel) {}
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog("Select Photo Source", isPresented: $showSource, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { source = .camera; isPicker = true }
            }
            Button("Choose from Gallery") { source = .photoLibrary; isPicker = true }
            if image != nil { Button("Remove Current Photo", role: .destructive) { image = nil } }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $isPicker) {
            ImagePicker(selectedImage: $image, isPresented: $isPicker, sourceType: source)
        }
    }
}

// MARK: Menge + Einheit + Stepper
struct QuantityMeasureRow: View {
    @Binding var units: String
    @Binding var measure: String
    var range: ClosedRange<Int> = 1...999

    private var value: Int { Int(units) ?? range.lowerBound }
    private var atMin: Bool { value <= range.lowerBound }
    private var atMax: Bool { value >= range.upperBound }
    private let controlHeight: CGFloat = 34

    var body: some View {
        HStack(spacing: 12) {
            TextField("Units", text: $units)
                .keyboardType(.numberPad)
                .frame(width: 70, height: controlHeight)
                .multilineTextAlignment(.leading)
                .textFieldStyle(.roundedBorder)
                .onChange(of: units) { oldValue, newValue in
                    let digits = newValue.filter { $0.isNumber }
                    let intVal = Int(digits) ?? range.lowerBound
                    let clamped = min(max(intVal, range.lowerBound), range.upperBound)
                    let normalized = String(clamped)
                    if normalized != units { units = normalized }
                }
            TextField("Measure", text: $measure)
                .frame(height: controlHeight)
                .multilineTextAlignment(.leading)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1)
                .accessibilityLabel("Einheit")
            Spacer()
            HStack(spacing: 12) {
                Button { decrement() } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: controlHeight, height: controlHeight)
                        .background(Capsule().fill(atMin ? Color.gray.opacity(0.35) : Color.accentColor))
                }
                .disabled(atMin)
                .accessibilityLabel("Menge verringern")
                Button { increment() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: controlHeight, height: controlHeight)
                        .background(Capsule().fill(atMax ? Color.gray.opacity(0.35) : Color.accentColor))
                }
                .disabled(atMax)
                .accessibilityLabel("Menge erhöhen")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func decrement() { var v = value; if v > range.lowerBound { v -= 1; units = String(v); lightHaptic() } }
    private func increment() { var v = value; if v < range.upperBound { v += 1; units = String(v); lightHaptic() } }
}

// MARK: Preisfeld mit lokaler Formatierung
struct PriceField: View {
    @Binding var price: String
    var showCurrencySymbol: Bool = true
    @State private var internalText: String = ""
    @State private var suppressExternalSync = false
    @State private var lastSyncedRawPrice: String = ""
    private var locale: Locale { .current }
    private var decimalSeparator: String { locale.decimalSeparator ?? "." }
    private var allowedChars: Set<Character> { Set("0123456789" + decimalSeparator) }
    private let fieldWidth: CGFloat = 70

    var body: some View {
        HStack(spacing: 6) {
            TextField("Price", text: Binding(
                get: { internalText.isEmpty ? displayStringFromStoredPrice() : internalText },
                set: { newVal in
                    suppressExternalSync = true
                    let filtered = newVal.filter { allowedChars.contains($0) }
                    var result = ""
                    var separatorUsed = false
                    for ch in filtered {
                        if ch == Character(decimalSeparator) {
                            if separatorUsed { continue }
                            separatorUsed = true
                        }
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
            .accessibilityLabel("Preis")
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
        // Zeigt den gespeicherten Preis im lokalen Format an
        let normalized = price.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else { return price.replacingOccurrences(of: ".", with: decimalSeparator) }
        var raw = String(value)
        // Entferne trailing .0 für schönere Darstellung
        if raw.hasSuffix(".0") { raw.removeLast(2) }
        return raw.replacingOccurrences(of: ".", with: decimalSeparator)
    }

    private func syncFromBindingIfNeeded(force: Bool) {
        guard !suppressExternalSync else { return }
        let currentRaw = price
        // Nur synchronisieren wenn internalText leer (Initialisierung) oder erzwungen
        if force || currentRaw != lastSyncedRawPrice {
            internalText = displayStringFromStoredPrice()
            lastSyncedRawPrice = currentRaw
        }
    }
}
