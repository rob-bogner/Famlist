// ReusableInputs.swift
// Wiederverwendbare Eingabe-Bausteine
import SwiftUI
import UIKit

// Foto-Auswahl (Kamera / Galerie)
struct PhotoField: View {
    @Binding var image: UIImage?
    @State private var isPicker = false
    @State private var showSource = false
    @State private var source: UIImagePickerController.SourceType = .photoLibrary

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable().scaledToFit()
                    .frame(width: 100, height: 100)
                    .roundedCorners(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                    .onTapGesture { showSource = true }
            } else {
                Button { showSource = true } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .resizable().scaledToFit()
                            .frame(width: 32, height: 32)
                            .foregroundColor(.gray)
                        Text("Add Photo").font(.subheadline).foregroundColor(.gray)
                    }
                    .frame(width: 100, height: 100)
                    .roundedCorners(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .confirmationDialog("Select Photo Source", isPresented: $showSource, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { source = .camera; isPicker = true }
            }
            Button("Choose from Gallery") { source = .photoLibrary; isPicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $isPicker) {
            ImagePicker(selectedImage: $image, isPresented: $isPicker, sourceType: source)
        }
    }
}

// Menge + Einheit + Stepper
struct QuantityMeasureRow: View {
    @Binding var units: String
    @Binding var measure: String
    var body: some View {
        HStack {
            TextField("Units", text: $units)
                .keyboardType(.numberPad)
                .frame(width: 70)
                .multilineTextAlignment(.leading)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1)
            TextField("Measure", text: $measure)
                .multilineTextAlignment(.leading)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1)
            Spacer()
            HStack(spacing: 10) {
                Button { decrement() } label: { Image(systemName: "minus.circle").font(.title).foregroundColor(Color.accentColor) }
                Button { increment() } label: { Image(systemName: "plus.circle").font(.title).foregroundColor(Color.accentColor) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func decrement() { var v = Int(units) ?? 1; if v > 1 { v -= 1; units = String(v) } }
    private func increment() { var v = Int(units) ?? 1; if v < 999 { v += 1; units = String(v) } }
}

// Preisfeld mit lokaler Formatierung
struct PriceField: View {
    @Binding var price: String
    private var formatter: NumberFormatter {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.locale = .current; return f
    }
    var body: some View {
        TextField(
            "Price",
            value: Binding(get: { Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0.0 }, set: { price = formatter.string(from: NSNumber(value: $0)) ?? "" }),
            formatter: formatter
        )
        .keyboardType(.decimalPad)
        .textFieldStyle(.roundedBorder)
        .lineLimit(1)
    }
}
