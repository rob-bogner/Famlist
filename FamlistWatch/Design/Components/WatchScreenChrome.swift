/*
 WatchScreenChrome.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Rahmen jedes Screens wie im Design (208 × 248): Hintergrund, Titel oben links (left 14, top 10,
   Höhe 22, Outfit 17/600, −0.01em, accentText), Inhalt ab `contentTop`, abgeschnitten wie overflow: hidden.

 🔰 Notes for Beginners:
 - Die System-Navigationsleiste ist ausgeblendet: watchOS 26 setzt Toolbar-Titel in eine eigene Zeile
   unter die Uhrzeit (Screenshot 26.09.2026), das Design hat Titel und Uhrzeit in einer Zeile.
   Die Uhrzeit rechts zeichnet watchOS weiterhin selbst.
 - Unterseiten zeigen „‹ Titel“ als Zurück-Knopf (WatchItem.dc.html).
 - Maße gelten ab der Bildschirmkante (ignoresSafeArea), wie die absolut positionierten Elemente im HTML.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct WatchScreenChrome: ViewModifier {
    let title: String
    let contentTop: CGFloat
    var w = WatchTheme()
    var onBack: (() -> Void)?

    func body(content: Content) -> some View {
        ZStack(alignment: .topLeading) {
            WatchBackground(w: w)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
                .padding(.top, contentTop)
            header
                .padding(.leading, 14)
                .padding(.top, 10)
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    @ViewBuilder private var header: some View {
        if let onBack {
            Button(action: onBack) { titleText("‹ \(title)") }
                .buttonStyle(.plain)
                .accessibilityLabel("Zurück zu \(title)")
        } else {
            titleText(title).accessibilityAddTraits(.isHeader)
        }
    }

    private func titleText(_ text: String) -> some View {
        Text(text)
            .font(WatchFont.outfit(17, 600))
            .tracking(-0.17)
            .foregroundStyle(w.accentText)
            .lineLimit(1)
            .frame(height: 22)
            .contentShape(Rectangle())
    }
}

extension View {
    /// Screen-Rahmen mit Titel; `onBack` macht daraus eine Unterseite mit „‹ Titel“.
    func watchScreen(_ title: String, contentTop: CGFloat, w: WatchTheme = WatchTheme(),
                     onBack: (() -> Void)? = nil) -> some View {
        modifier(WatchScreenChrome(title: title, contentTop: contentTop, w: w, onBack: onBack))
    }
}
