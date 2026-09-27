/*
 WatchIcon.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Original-SVG-Pfade der Watch-Designs, die nicht schon im geteilten Icon-Katalog (Icon.swift) stehen.

 🔰 Notes for Beginners:
 - Gezeichnet mit SVGIcon/SVGFilledIcon (viewBox 0 0 24 24, Strichstärke in viewBox-Einheiten).
 - Haken, Plus, Minus und Stern kommen aus Icon (gleiche Pfade wie im Design).
 ------------------------------------------------------------------------
 */

import SwiftUI

enum WatchIcon {
    /// „Alle abhaken“ (WatchList.dc.html).
    static let checkAll: [SVGElement] = [.path("M18 6 7 17l-5-5M22 10l-7.5 7.5L13 16")]
    /// Mikrofon (WatchAdd.dc.html).
    static let mic: [SVGElement] = [.path("M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3zM5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21")]
    /// Einkaufswagen ohne Räder (WatchFace.dc.html, Smart Stack).
    static let cart: [SVGElement] = [.path("M3 4h2.5l2 11h10.5l2-8H7")]
    /// Haken im Erledigt-Ring (WatchDone.dc.html: viewBox 96, „M33 49l10 10 21-22“, Strich 6) auf 24 umgerechnet.
    static let doneCheck: [SVGElement] = [.path("M8.25 12.25l2.5 2.5 5.25-5.5")]
    /// Strichstärke von doneCheck in 24er-Einheiten (6 / 4).
    static let doneCheckLineWidth: CGFloat = 1.5
}
