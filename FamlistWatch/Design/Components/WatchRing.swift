/*
 WatchRing.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ring-Anzeige wie die SVG-Kreise im Design: Listen 30 pt / Strich 3,5; Komplikation 38 pt / Strich 4.
   Spur weiß .16, Fortschritt accentText mit runden Enden, Start oben, im Uhrzeigersinn.

 🔰 Notes for Beginners:
 - Radius = (Größe − Strich) / 2, also r = 13,25 bzw. 17 wie im SVG.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct WatchRing: View {
    var w = WatchTheme()
    let fraction: Double
    var size: CGFloat = 30
    var lineWidth: CGFloat = 3.5
    var label: String? = nil

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.16), lineWidth: lineWidth)
            Circle().trim(from: 0, to: max(0, min(fraction, 1)))
                .stroke(w.accentText, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let label {
                Text(label).font(WatchFont.dm(11, 600)).foregroundStyle(.white)
            }
        }
        .padding(lineWidth / 2)
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack {
        WatchRing(fraction: 1.0 / 3.0)
        WatchRing(fraction: 1.0 / 3.0, size: 38, lineWidth: 4, label: "4")
    }
    .padding()
    .background(Color.black)
}
