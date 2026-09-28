/*
 MonthSwitcher.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Monatswechsel der Auswertung: Glas-Knopf „Vormonat“, „September 2026“, Glas-Knopf „Nächster Monat“.

 🔰 Notes for Beginners:
 - Board: Glas-Knöpfe 36 mit Chevron 16 (Strich 2,2), Titel Outfit 18/600, Abstand zum Segment 12.
 - „weiter“ ist im aktuellen Monat gesperrt, „zurück“ vor dem ersten Bon; gesperrt = 40 % Deckkraft
   (nicht gestaltet, Übergangslösung).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct MonthSwitcher: View {
    let title: String
    let canGoBack: Bool
    let canGoForward: Bool
    let k: SheetTheme
    var onBack: () -> Void = {}
    var onForward: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            button(Icon.chevronLeft, label: "Vormonat", enabled: canGoBack, action: onBack)
            Spacer(minLength: 8)
            Text(title)
                .font(AppFont.outfit(18, 600))
                .foregroundStyle(k.text)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            button(Icon.chevronRight, label: "Nächster Monat", enabled: canGoForward, action: onForward)
        }
    }

    private func button(_ icon: [SVGElement], label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        CircleCloseButton(k: k, size: 36, iconSize: 16, lineWidth: 2.2, icon: icon, action: action)
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.4)
            .accessibilityLabel(label)
    }
}

#Preview("Monatswechsel") {
    MonthSwitcher(title: "September 2026", canGoBack: true, canGoForward: false, k: SheetTheme(.light)).padding()
}

#Preview("Monatswechsel – Dark") {
    MonthSwitcher(title: "September 2026", canGoBack: true, canGoForward: true, k: SheetTheme(.dark))
        .padding()
        .background(Color.black)
}
