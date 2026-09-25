/*
 ListAccountAvatar.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Runder Avatar mit Initiale (Verlauf light → deep) oder Profilfoto.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ListManagementScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Runder Avatar mit Initiale: Verlauf 150° light → deep, inset 0 1px 0 rgba(255,255,255,.45), Outfit 600 weiß.
struct ListAccountAvatar: View {
    let t: ListAccountTokens
    let initial: String
    let size: CGFloat
    let fontSize: CGFloat
    /// Profilfoto; ohne Foto zeigt der Avatar die Initiale wie im Design.
    var image: UIImage? = nil

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .accessibilityHidden(true)
        } else {
            initialView
        }
    }

    private var initialView: some View {
        Text(initial)
            .font(AppFont.outfit(fontSize, 600))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(CSSBox(shape: Circle(), paint: t.avatar,
                               shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.45))]))
    }
}

#Preview("ListAccountAvatar") {
    ListAccountAvatar(t: ListAccountTokens(.light), initial: "R", size: 72, fontSize: 28)
        .padding(20)
}

#Preview("ListAccountAvatar – Dark") {
    ListAccountAvatar(t: ListAccountTokens(.dark), initial: "R", size: 72, fontSize: 28)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
