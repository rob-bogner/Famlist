/*
 WatchFaceGallery.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Nur DEBUG: Smart-Stack-Karte und beide Komplikationen an ihren Plätzen aus WatchFace.dc.html – für den
   Pixelvergleich der Widget-Ansichten. Uhrzeit und Datum zeichnet watchOS; sie fehlen hier.
 - Die Hintergründe (Karte, Kreise weiß .1) stellt auf dem Zifferblatt das System über containerBackground;
   hier sind sie mit den Design-Werten nachgebildet.
 ------------------------------------------------------------------------
 */

#if DEBUG
import SwiftUI

struct WatchFaceGallery: View {
    var w = WatchTheme()

    var body: some View {
        ZStack(alignment: .topLeading) {
            WatchBackground(w: w)
            WatchSmartStackView(w: w, state: .placeholder)
                .padding(.vertical, 11).padding(.horizontal, 13)           // Rand 1 + padding 10/12
                .frame(width: 188, height: 72, alignment: .topLeading)
                .background(WatchCardBackground(w: w, radius: 20))
                .offset(x: 10, y: 116)
            circle { WatchRingComplicationView(w: w, state: .placeholder) }
                .offset(x: 22, y: 192)
            circle { WatchAddComplicationView(w: w) }
                .offset(x: 142, y: 192)
        }
        .frame(width: 208, height: 248, alignment: .topLeading)
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func circle(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .frame(width: 44, height: 44)
            .background(Circle().fill(Color.white.opacity(0.1)))
    }
}

#Preview {
    WatchFaceGallery()
}
#endif
