/*
 WatchSectionLabel.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Abschnittstitel: DM 11/600, letter-spacing 0.06em (0,66 pt), Großbuchstaben, weiß .6,
   padding 4px 4px 0 4px.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct WatchSectionLabel: View {
    var w = WatchTheme()
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(WatchFont.dm(11, 600))
            .tracking(0.66)
            .foregroundStyle(w.sub)
            .lineLimit(1)
            .watchLineBox(WatchFont.dmLineHeight(11, 600))
            .padding(.horizontal, 4)
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    WatchSectionLabel(text: "Obst & Gemüse")
        .padding()
        .background(Color.black)
}
