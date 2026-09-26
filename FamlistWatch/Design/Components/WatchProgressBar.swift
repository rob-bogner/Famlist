/*
 WatchProgressBar.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Fortschrittsbalken: 5 hoch, Radius 3 (bei 5 pt Höhe wirkt das wie eine Kapsel), Spur weiß .14,
   Füllung linear-gradient(90deg, light, accent) über die gefüllte Breite.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct WatchProgressBar: View {
    var w = WatchTheme()
    let fraction: Double

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(w.track)
                Capsule().fill(w.fill).frame(width: g.size.width * max(0, min(fraction, 1)))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

#Preview {
    WatchProgressBar(fraction: 1.0 / 3.0)
        .padding()
        .background(Color.black)
}
