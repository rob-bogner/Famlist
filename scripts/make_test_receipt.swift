// make_test_receipt.swift – erzeugt das Bon-Bild für FamlistUITests/LiveReceiptPriceUITests.
// Aufruf: swift scripts/make_test_receipt.swift /tmp/bon.png && xcrun simctl addmedia <Simulator-ID> /tmp/bon.png
// Das Bild muss das neueste Foto der Simulator-Mediathek sein (der Test wählt das Foto oben links).
import AppKit
let lines = ["EDEKA", "Edeka Markt Test", "25.09.2026 18:42", "", "EUR",
             "LIVETEST QUITTENGELEE      2,49 A",
             "LIVETEST BIRNENSAFT        2,58 A",
             "2 Stk x 1,29",
             "--------------------------------",
             "SUMME                EUR 5,07"]
let w = 900, lh = 56, h = lh * (lines.count + 2)
let img = NSImage(size: NSSize(width: w, height: h))
img.lockFocus()
NSColor.white.setFill(); NSRect(x: 0, y: 0, width: w, height: h).fill()
let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 34, weight: .medium), .foregroundColor: NSColor.black]
for (i, l) in lines.enumerated() { (l as NSString).draw(at: NSPoint(x: 40, y: h - lh * (i + 2)), withAttributes: attrs) }
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
