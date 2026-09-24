/*
 ItemThumbnailTile.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Bild-Kachel der Artikel-Karte: 64 × 64, Radius 18. Ohne Foto das durchgestrichene Kamera-Icon.

 🔰 Notes for Beginners:
 - Ersetzt ItemThumbnail (defaultImage-Asset). Ein vorhandenes Foto füllt die Kachel (scaledToFill).

 📝 Last Change:
 - Aus ListScreen des Design-Pakets MyListUI übernommen, um echtes Foto ergänzt.
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

/// 64 pt product image tile with placeholder.
struct ItemThumbnailTile: View {
    let t: ListTheme
    let image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                SVGIcon(Icon.cameraOff, size: 24, color: t.thumbIcon, lineWidth: 1.7)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RR(18))
        .background(CSSBox(shape: RR(18), paint: t.thumb, shadows: t.thumbShadow))
        .contentShape(RR(18))
    }
}

#Preview {
    ItemThumbnailTile(t: ListTheme(.light), image: nil)
        .padding()
}
