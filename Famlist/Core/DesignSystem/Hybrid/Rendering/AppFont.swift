//  AppFont.swift
//  Famlist (aus dem Design-Paket MyListUI übernommen)
//
//  Schriften exakt wie im Design:
//  • Outfit  (Variable Font, Achse wght)        – Überschriften, Zahlen
//  • DM Sans (Variable Font, Achsen opsz + wght) – Fließtext, Labels, Buttons
//
//  Das Design lädt DM Sans mit optischer Größe (opsz 9…40). Der Browser setzt
//  opsz automatisch auf die Schriftgröße (font-optical-sizing: auto).
//  Damit die Glyphen identisch sind, wird opsz hier ebenso auf die Größe gesetzt.
//
//  Größen: Bei der iOS-Standardschrift pixelgenau wie im Design. Wählt der Nutzer in iOS eine größere
//  Schrift, wächst der Text mit – höchstens um `maxScale` (Robert: „nichts unleserlich, gestaucht oder
//  schwer bedienbar“, Audit 25.09.2026). Kleiner als das Design wird nichts.

import SwiftUI
import UIKit
import CoreText

enum AppFont {
    enum Family: String {
        case outfit = "Outfit"
        case dmSans = "DM Sans"
    }

    private static let wghtAxis = 0x7767_6874 // 'wght'
    private static let opszAxis = 0x6F70_737A // 'opsz'
    /// Cache und Skalierung werden von mehreren Threads gelesen (SwiftUI-Layout) → mit Sperre.
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: UIFont] = [:]
    nonisolated(unsafe) private static var storedScale: CGFloat = 1

    /// Obergrenze der Vergrößerung: iOS-Textgröße XXL (21 statt 17 pt, +24 %). Darüber würden die fest
    /// gestalteten Flächen (Dock, Pillen, Karten) Text abschneiden – geprüft per ScreenTourUITests.
    static let maxScale: CGFloat = 21.0 / 17.0

    /// Aktueller Faktor (1 = Design). Gesetzt von RootView aus der iOS-Schriftgröße.
    static var scale: CGFloat {
        get { lock.withLock { storedScale } }
        set { lock.withLock { storedScale = min(max(newValue, 1), maxScale) } }
    }

    /// Faktor für eine iOS-Schriftgröße: Verhältnis des Fließtexts (body) zu 17 pt, begrenzt.
    static func scale(for category: UIContentSizeCategory) -> CGFloat {
        let body = UIFont.preferredFont(forTextStyle: .body,
                                        compatibleWith: UITraitCollection(preferredContentSizeCategory: category)).pointSize
        return min(max(body / 17, 1), maxScale)
    }

    /// UIFont mit exakten Variations-Achsen, skaliert mit `scale`.
    /// `scaled: false` hält die Designgröße fest – nur für Bedienleisten ohne Platz zum Wachsen (Dock),
    /// dort zeigt iOS stattdessen die Großanzeige beim langen Drücken (wie bei Tab-Leisten).
    static func ui(_ family: Family, _ baseSize: CGFloat, _ weight: CGFloat, scaled: Bool = true) -> UIFont {
        let size = (baseSize * (scaled ? scale : 1) * 2).rounded() / 2   // halbe Punkte, stabil für den Cache
        let key = "\(family.rawValue)|\(size)|\(weight)"
        if let cached = lock.withLock({ cache[key] }) { return cached }
        var axes: [NSNumber: NSNumber] = [NSNumber(value: wghtAxis): NSNumber(value: Double(weight))]
        if family == .dmSans {
            axes[NSNumber(value: opszAxis)] = NSNumber(value: Double(min(max(size, 9), 40)))
        }
        let variationKey = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: family.rawValue,
            variationKey: axes
        ])
        let font = UIFont(descriptor: descriptor, size: size)
        lock.withLock { cache[key] = font }
        return font
    }

    /// Outfit – `font-family: 'Outfit'; font-size: size; font-weight: weight`
    static func outfit(_ size: CGFloat, _ weight: CGFloat, scaled: Bool = true) -> Font {
        Font(ui(.outfit, size, weight, scaled: scaled) as CTFont)
    }

    /// DM Sans – `font-family: 'DM Sans'; font-size: size; font-weight: weight`
    static func dm(_ size: CGFloat, _ weight: CGFloat, scaled: Bool = true) -> Font {
        Font(ui(.dmSans, size, weight, scaled: scaled) as CTFont)
    }
}
