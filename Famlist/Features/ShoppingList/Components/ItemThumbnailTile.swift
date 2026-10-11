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
 - Freigestellte Fotos passen ganz in die Kachel (30.09.2026).
 - Aus ListScreen des Design-Pakets MyListUI übernommen, um echtes Foto ergänzt.
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

/// 64 pt product image tile with placeholder.
/// `flush`: Artikelkarte, Variante A (12.10.2026) – Foto so hoch wie die Karte (92), links bündig, die linken
/// Ecken folgen der Karte (Radius 23 innerhalb des 1-pt-Rands), rechts gerade, ohne Schatten.
struct ItemThumbnailTile: View {
    let t: ListTheme
    let image: UIImage?
    var flush = false

    private var size: CGFloat { flush ? 92 : 64 }
    private var shape: UnevenRoundedRectangle {
        flush ? UnevenRoundedRectangle(topLeadingRadius: 23, bottomLeadingRadius: 23, bottomTrailingRadius: 0,
                                       topTrailingRadius: 0, style: .continuous)
              : UnevenRoundedRectangle(cornerRadii: .init(topLeading: 18, bottomLeading: 18, bottomTrailing: 18,
                                                          topTrailing: 18), style: .continuous)
    }

    var body: some View {
        ZStack {
            if let image, ProductCutout.isCutout(image) {
                // Freigestelltes Foto: ganz sichtbar auf der Kachel, wie die Produktbilder.
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(flush ? 8 : 5)
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                SVGIcon(Icon.cameraOff, size: flush ? 28 : 24, color: t.thumbIcon, lineWidth: 1.7)
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .background(CSSBox(shape: shape, paint: t.thumb, shadows: flush ? [] : t.thumbShadow))
        .contentShape(shape)
    }
}

#Preview {
    ItemThumbnailTile(t: ListTheme(.light), image: nil)
        .padding()
}

#Preview("Dark") {
    ItemThumbnailTile(t: ListTheme(.dark), image: nil)
        .padding()
        .background(Color.hex("#0A1416"))
}
