/*
 ReceiptSampleBon.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zeichnet den Beispiel-Bon aus ReceiptDetail.dc.html als Foto (für Vorschauen und den Design-Modus).

 🔰 Notes for Beginners:
 - Papier #F4F1EA, 250 × 480, Padding 18/16, Schrift SF Mono 10,5 (Zeilenhöhe 1,45 → 15,2), Farbe #3A3833.
 - Kopf zentriert, Positionen links/rechts, „SUMME“ fett – wie im Design.
 - Gerendert mit Maßstab 3, damit das Foto im Detail scharf bleibt.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import UIKit

enum ReceiptSampleBon {
    enum Line { case center(String, bold: Bool), row(String, String, bold: Bool), empty }

    static let designLines: [Line] = [
        .center("EDEKA Center", bold: true), .center("Leopoldstr. 82, München", bold: false), .empty,
        .row("KERRYGOLD BUTTER", "2,49 A", bold: false), .row("ALPRO SOJA DRINK", "2,29 A", bold: false),
        .row("KOKOSM. 400ML", "1,39 A", bold: false), .row("MANDELDR.O.Z.", "1,85 A", bold: false),
        .row("FAIRGL.VM SCHOKO", "3,49 A", bold: false), .empty, .row("SUMME", "11,51", bold: true)
    ]

    static let size = CGSize(width: 250, height: 480)

    static func image(lines: [Line] = designLines) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor(red: 0xF4 / 255, green: 0xF1 / 255, blue: 0xEA / 255, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            var y: CGFloat = 18
            for line in lines {
                draw(line, y: y)
                y += 15.2
            }
        }
    }

    private static func draw(_ line: Line, y: CGFloat) {
        let width = size.width - 32
        switch line {
        case .empty:
            return
        case .center(let text, let bold):
            let attributed = NSAttributedString(string: text, attributes: attributes(bold: bold, alignment: .center))
            attributed.draw(in: CGRect(x: 16, y: y, width: width, height: 16))
        case .row(let left, let right, let bold):
            NSAttributedString(string: left, attributes: attributes(bold: bold, alignment: .left))
                .draw(in: CGRect(x: 16, y: y, width: width, height: 16))
            NSAttributedString(string: right, attributes: attributes(bold: bold, alignment: .right))
                .draw(in: CGRect(x: 16, y: y, width: width, height: 16))
        }
    }

    private static func attributes(bold: Bool, alignment: NSTextAlignment) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        return [.font: UIFont.monospacedSystemFont(ofSize: 10.5, weight: bold ? .bold : .regular),
                .foregroundColor: UIColor(red: 0x3A / 255, green: 0x38 / 255, blue: 0x33 / 255, alpha: 1),
                .paragraphStyle: paragraph]
    }
}
