/*
 WatchFont.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Outfit (Titel, Zahlen) und DM Sans (Text) als variable Schriften, exakt wie AppFont im iOS-Target.

 🔰 Notes for Beginners:
 - Font.custom(...).weight(...) wählt bei variablen Schriften nicht zuverlässig die Achse. Deshalb werden
   wie in AppFont die Achsen direkt gesetzt: wght = Schriftstärke, bei DM Sans zusätzlich opsz = Größe
   (der Browser macht das mit font-optical-sizing: auto). CoreText statt UIKit, damit es auf watchOS läuft.
 - Die Schriftdateien stehen im Watch-Target unter UIAppFonts (FamlistWatch/Info.plist).
 ------------------------------------------------------------------------
 */

import CoreText
import SwiftUI

enum WatchFont {
    private static let wghtAxis = 0x7767_6874 // 'wght'
    private static let opszAxis = 0x6F70_737A // 'opsz'
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: CTFont] = [:]
    nonisolated(unsafe) private static var storedScale: CGFloat = 1

    /// Obergrenze der Vergrößerung (+24 % wie auf dem iPhone). Darüber passen die fest gestalteten Knöpfe
    /// (FAB, „Alle abhaken“, Stepper) nicht mehr – Zeilen und Texte wachsen bis dahin mit.
    static let maxScale: CGFloat = 1.24

    /// Aktueller Faktor (1 = Design). Gesetzt von WatchFontScaling aus der Textgröße der Uhr.
    static var scale: CGFloat {
        get { lock.withLock { storedScale } }
        set { lock.withLock { storedScale = min(max(newValue, 1), maxScale) } }
    }

    /// Faktor aus @ScaledMetric(relativeTo: .body) mit Basis 100: 100 = Standard, 120 = 20 % größer.
    static func scale(bodyMetric: CGFloat) -> CGFloat {
        min(max(bodyMetric / 100, 1), maxScale)
    }

    /// Outfit – `font-family: 'Outfit'; font-size: size; font-weight: weight`
    static func outfit(_ size: CGFloat, _ weight: CGFloat = 600) -> Font {
        Font(ctFont(family: "Outfit", size: scaled(size), weight: weight, opticalSize: false))
    }

    /// DM Sans – `font-family: 'DM Sans'; font-size: size; font-weight: weight`
    static func dm(_ size: CGFloat, _ weight: CGFloat = 400) -> Font {
        Font(ctFont(family: "DM Sans", size: scaled(size), weight: weight, opticalSize: true))
    }

    /// Designgröße × Faktor, auf halbe Punkte gerundet (stabil für den Cache; Faktor 1 = unverändert).
    static func scaled(_ size: CGFloat) -> CGFloat {
        let factor = scale
        return factor == 1 ? size : (size * factor * 2).rounded() / 2
    }

    /// CSS `line-height: normal` von Outfit (Ascender + Descender + Zeilenabstand aus der Schrift = 1,26 × Größe).
    static func outfitLineHeight(_ size: CGFloat, _ weight: CGFloat = 600) -> CGFloat {
        lineHeight(ctFont(family: "Outfit", size: scaled(size), weight: weight, opticalSize: false))
    }

    /// CSS `line-height: normal` von DM Sans (1,302 × Größe).
    static func dmLineHeight(_ size: CGFloat, _ weight: CGFloat = 400) -> CGFloat {
        lineHeight(ctFont(family: "DM Sans", size: scaled(size), weight: weight, opticalSize: true))
    }

    private static func lineHeight(_ font: CTFont) -> CGFloat {
        CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
    }

    private static func ctFont(family: String, size: CGFloat, weight: CGFloat, opticalSize: Bool) -> CTFont {
        let key = "\(family)|\(size)|\(weight)"
        if let cached = lock.withLock({ cache[key] }) { return cached }
        var axes: [NSNumber: NSNumber] = [NSNumber(value: wghtAxis): NSNumber(value: Double(weight))]
        if opticalSize { axes[NSNumber(value: opszAxis)] = NSNumber(value: Double(min(max(size, 9), 40))) }
        let attributes: [CFString: Any] = [kCTFontFamilyNameAttribute: family, kCTFontVariationAttribute: axes]
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        let font = CTFontCreateWithFontDescriptor(descriptor, size, nil)
        lock.withLock { cache[key] = font }
        return font
    }
}
