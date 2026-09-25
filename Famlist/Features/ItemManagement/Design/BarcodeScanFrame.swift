/*
 BarcodeScanFrame.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Scan-Rahmen 280 × 180 des Barcode-Scanners: vier Ecken, Scan-Linie, Barcode-Platzhalter.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ItemExtraScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI


/// Scan-Rahmen 280 × 180: vier Ecken, Scan-Linie mit Glow, Barcode-Platzhalter (Reihenfolge wie im DOM).
struct BarcodeScanFrame: View {
    let accent: Color

    /// `<rect x width>` des Barcode-SVG (y 0, Höhe 80)
    private static let bars: [(CGFloat, CGFloat)] = [
        (0, 4), (8, 2), (14, 6), (24, 2), (30, 4), (38, 2), (44, 6), (54, 2), (60, 4),
        (68, 2), (74, 6), (84, 4), (92, 2), (98, 6), (108, 2), (114, 4), (122, 2), (128, 6)
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            corner.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            corner.scaleEffect(x: -1, y: 1).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            corner.scaleEffect(x: 1, y: -1).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            corner.scaleEffect(x: -1, y: -1).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            // Scan-Linie: links/rechts 20, top 88, Höhe 3, Radius 2, box-shadow 0 0 16px accent
            Color.clear
                .frame(width: 240, height: 3)
                .background(CSSBox(shape: RR(2), paint: .color(accent), shadows: [.drop(0, 0, 16, 0, accent)]))
                .padding(.leading, 20)
                .padding(.top, 88)

            // Barcode: left 70, top 50, 140 × 80, fill rgba(255,255,255,.55)
            Path { p in
                for (x, w) in Self.bars {
                    p.addRect(CGRect(x: x, y: 0, width: w, height: 80))
                }
            }
            .fill(Color.rgba(255, 255, 255, 0.55))
            .frame(width: 140, height: 80)
            .padding(.leading, 70)
            .padding(.top, 50)
        }
        .frame(width: 280, height: 180)
    }

    /// Ecke oben links; content-box 34 + Rahmen 4 → Außenmaß 38.
    private var corner: some View {
        BarcodeScanCornerShape()
            .fill(accent, style: FillStyle(eoFill: true))
            .frame(width: 38, height: 38)
    }
}

/// `border-width: 4px 0 0 4px; border-top-left-radius: 18px` auf 34 × 34 (content-box):
/// Außenkante Radius 18, Innenkante Radius 18 − 4 = 14, gerade Enden (butt).
private struct BarcodeScanCornerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addPath(UnevenRoundedRectangle(topLeadingRadius: 18, style: .circular)
            .path(in: CGRect(x: rect.minX, y: rect.minY, width: 38, height: 38)))
        p.addPath(UnevenRoundedRectangle(topLeadingRadius: 14, style: .circular)
            .path(in: CGRect(x: rect.minX + 4, y: rect.minY + 4, width: 34, height: 34)))
        return p
    }
}

// MARK: - Preisverlauf

// Quelle: Design/html/PriceHistory.dc.html (+ PriceHistoryDark.dc.html)
//
//  Hintergrund: „Artikel bearbeiten“ (inkl. eigener Liste), weichgezeichnet 3 + Abdunkelung.
//  Sheet 754, unten bündig, Innenabstand 10 / 20 / 24:
//  Griff 5 → 12 → Titelzeile 44 → 16 → Produkt (Kachel 52) → 16 → 3 Kennzahlen (Abstand 8) → 16 →

#Preview("BarcodeScanFrame") {
    BarcodeScanFrame(accent: SheetTheme(.light).accent)
        .frame(width: 280, height: 180)
        .padding(20)
}

#Preview("BarcodeScanFrame – Dark") {
    BarcodeScanFrame(accent: SheetTheme(.dark).accent)
        .frame(width: 280, height: 180)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
