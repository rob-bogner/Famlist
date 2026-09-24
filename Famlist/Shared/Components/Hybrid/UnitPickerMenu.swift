/*
 UnitPickerMenu.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Maßeinheit-Auswahl der Hybrid-Sheets: flexible Breite, Höhe 52, Radius 16, Doppel-Chevron rechts.

 🔰 Notes for Beginners:
 - Heißt im Design `UnitPickerButton`. Tippen öffnet hier ein System-Menü mit allen Measure-Werten
   statt des bisherigen Rad-Pickers im Sheet.
 - Gespeichert wird der rohe Measure-Wert (z. B. "pack"); angezeigt wird localizedName (z. B. „Packung“).

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen, als Menu an das Measure-Binding angebunden.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Maßeinheit-Auswahl: flexible Breite, Höhe 52, Radius 16, Doppel-Chevron rechts.
struct UnitPickerMenu: View {
    let k: SheetTheme
    @Binding var measure: String

    private var displayValue: String? {
        measure.isEmpty ? nil : Measure.fromExternal(measure).localizedName
    }

    var body: some View {
        Menu {
            Button("Keine Einheit") { measure = "" }
            Divider()
            ForEach(Measure.allCases, id: \.self) { unit in
                Button(unit.localizedName) { measure = unit.rawValue }
            }
        } label: {
            label
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("Maßeinheit: \(displayValue ?? "keine")")
    }

    private var label: some View {
        HStack(spacing: 0) {
            Text(displayValue ?? "Maßeinheit")
                .font(AppFont.dm(16, displayValue == nil ? 400 : 500))
                .foregroundStyle(displayValue == nil ? k.sub : k.text)
                .lineLimit(1)
            Spacer(minLength: 0)
            SVGIcon(Icon.chevronsUpDown, size: 16, color: k.sub, lineWidth: 2.2)
        }
        .padding(.leading, 17)     // 1 border + 16 padding
        .padding(.trailing, 15)    // 1 border + 14 padding
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(CSSBox(shape: RR(16), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
        .contentShape(RR(16))
    }
}

#Preview {
    @Previewable @State var measure = "pack"
    UnitPickerMenu(k: SheetTheme(.light), measure: $measure)
        .padding(20)
}
