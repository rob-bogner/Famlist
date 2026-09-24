/*
 PhotoAddTile.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - „Foto hinzufügen“-Kachel: 104 × 104, Radius 26, gestrichelter 1,5-pt-Rahmen.
   Mit gesetztem Bild zeigt die Kachel das Foto.

 🔰 Notes for Beginners:
 - Tippen öffnet die Quellenauswahl (Kamera / Mediathek / Entfernen) wie das bisherige PhotoField.
 - Die Bildauswahl selbst ist der System-Picker (ImagePicker); er darf als System-Sheet erscheinen.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen, an Bildauswahl angebunden.
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

/// „Foto hinzufügen“-Kachel: 104 × 104, Radius 26, gestrichelter 1,5-pt-Rahmen.
struct PhotoAddTile: View {
    let k: SheetTheme
    @Binding var image: UIImage?

    @State private var showSource = false
    @State private var showPicker = false
    @State private var source: UIImagePickerController.SourceType = .photoLibrary

    var body: some View {
        Button(action: { showSource = true }) {
            tileContent
                .frame(width: 104, height: 104)
                .clipShape(RR(26))
                .background(CSSBox(shape: RR(26), paint: .color(k.field), border: image == nil ? 1.5 : 0,
                                   borderColor: k.dashed, dash: [4.5, 4.5]))
                .contentShape(RR(26))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(image == nil ? "Foto hinzufügen" : "Foto ändern")
        .confirmationDialog("Foto", isPresented: $showSource, titleVisibility: .hidden) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Foto aufnehmen") { source = .camera; showPicker = true }
            }
            Button("Aus Mediathek wählen") { source = .photoLibrary; showPicker = true }
            if image != nil {
                Button("Foto entfernen", role: .destructive) { image = nil }
            }
            Button("Abbrechen", role: .cancel) {}
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker(selectedImage: $image, isPresented: $showPicker, sourceType: source)
        }
    }

    @ViewBuilder
    private var tileContent: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            VStack(spacing: 6) {
                SVGIcon(Icon.camera, size: 26, color: k.accentText, lineWidth: 1.8)
                Text("Foto hinzufügen")
                    .font(AppFont.dm(12, 600))
                    .foregroundStyle(k.sub)
            }
        }
    }
}

#Preview {
    PhotoAddTile(k: SheetTheme(.light), image: .constant(nil))
        .padding(20)
}
