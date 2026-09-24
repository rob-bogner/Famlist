/*
 SVGIconShape.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Shape, das SVG-Elemente in der 24×24-viewBox auf die Zielgröße skaliert.

 🔰 Notes for Beginners:
 - Teil des Hybrid-Designs (Canvas „My List – Redesign“). Übersetzt CSS-Werte 1:1 nach SwiftUI.
   Umrechnungsregeln: siehe Core/DesignSystem/Hybrid/README.md.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct SVGIconShape: Shape {
    let elements: [SVGElement]

    func path(in rect: CGRect) -> Path {
        var p = Path()
        for e in elements {
            switch e {
            case .path(let d):
                p.addPath(SVGPathParser.parse(d))
            case .circle(let cx, let cy, let r):
                p.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
            case .rect(let x, let y, let w, let h, let rx):
                p.addRoundedRect(in: CGRect(x: x, y: y, width: w, height: h),
                                 cornerSize: CGSize(width: rx, height: rx), style: .circular)
            }
        }
        let s = min(rect.width, rect.height) / 24
        return p.applying(CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: rect.minX, ty: rect.minY))
    }
}
