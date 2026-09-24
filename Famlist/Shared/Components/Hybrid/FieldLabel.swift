/*
 FieldLabel.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Feld-Beschriftung 13/600 in Farbe sub, 4 pt Einzug.

 🔰 Notes for Beginners:
 - Baustein der Hybrid-Sheets. Maße und Farben 1:1 aus dem Design (siehe Core/DesignSystem/Hybrid/README.md).

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Feld-Beschriftung: 13/600, Farbe sub, 4 pt Einzug.
struct FieldLabel: View {
    let text: String
    let k: SheetTheme

    var body: some View {
        Text(text)
            .font(AppFont.dm(13, 600))
            .foregroundStyle(k.sub)
            .padding(.leading, 4)
    }
}
