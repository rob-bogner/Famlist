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
//  Größen sind fix (keine Dynamic-Type-Skalierung), damit das Layout pixelgenau bleibt.

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
    nonisolated(unsafe) private static var cache: [String: UIFont] = [:]

    /// UIFont mit exakten Variations-Achsen.
    static func ui(_ family: Family, _ size: CGFloat, _ weight: CGFloat) -> UIFont {
        let key = "\(family.rawValue)|\(size)|\(weight)"
        if let cached = cache[key] { return cached }
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
        cache[key] = font
        return font
    }

    /// Outfit – `font-family: 'Outfit'; font-size: size; font-weight: weight`
    static func outfit(_ size: CGFloat, _ weight: CGFloat) -> Font {
        Font(ui(.outfit, size, weight) as CTFont)
    }

    /// DM Sans – `font-family: 'DM Sans'; font-size: size; font-weight: weight`
    static func dm(_ size: CGFloat, _ weight: CGFloat) -> Font {
        Font(ui(.dmSans, size, weight) as CTFont)
    }
}
