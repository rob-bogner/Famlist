/*
 WatchCheckCircle.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Abhak-Kreis 26 pt. Offen: Rand 2 px rgba(accent,.55). Erledigt: Orb-Verlauf (accent bei 55 %),
   inset 0 1px 0 weiß .45, Haken 14 pt / Strich 3 weiß (Pfad M5 12.5l4.5 4.5L19 7.5).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct WatchCheckCircle: View {
    var w = WatchTheme()
    let isChecked: Bool

    var body: some View {
        ZStack {
            if isChecked {
                CSSBox(shape: Circle(), paint: w.checkFill, shadows: [.inner(0, 1, 0, 0, .white.opacity(0.45))])
                SVGIcon(Icon.check, size: 14, color: .white, lineWidth: 3)
            } else {
                Circle().strokeBorder(w.ring, lineWidth: 2)
            }
        }
        .frame(width: 26, height: 26)
    }
}

#Preview {
    HStack {
        WatchCheckCircle(isChecked: false)
        WatchCheckCircle(isChecked: true)
    }
    .padding()
    .background(Color.black)
}
