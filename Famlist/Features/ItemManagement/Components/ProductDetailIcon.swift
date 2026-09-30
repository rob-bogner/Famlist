/*
 ProductDetailIcon.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Icons der Karten in „Produktdetails“ (Pfade 1:1 aus ProductDetail.dc.html).

 🔰 Notes for Beginners:
 - Die Kategorie-Karte zeigt das Icon der gewählten Kategorie; ohne Kategorie `category`.

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import Foundation

/// SVG icons of the product detail cards.
enum ProductDetailIcon {
    static let category: [SVGElement] = [
        .path("M12 8c-3.5-2.5-8-.5-8 4.5 0 4 3 7.5 5 7.5 1.2 0 1.8-.6 3-.6s1.8.6 3 .6c2 0 5-3.5 5-7.5 0-5-4.5-7-8-4.5z"),
        .path("M12 8c0-2 1-3.5 3-4.5")
    ]
    static let unit: [SVGElement] = [.path("M6 7h12l2 13H4L6 7z"), .path("M9 7a3 3 0 0 1 6 0"), .path("M9.5 14h5")]
    static let trend: [SVGElement] = [.path("M3 17l6-6 4 4 8-8"), .path("M15 7h6v6")]
    /// Zauberstab „Nachbessern“ (PhotoCutoutDone).
    static let wand: [SVGElement] = [.path("M4 20L14 10"), .path("M15 4v2M15 12v2M11 8h2M17 8h2M12.2 5.2l1.4 1.4M16.4 9.4l1.4 1.4M16.4 6.6l1.4-1.4")]
    /// Funken „aus dem Foto erkannt“.
    static let sparkle: [SVGElement] = [.path("M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"), .path("M19 15.5l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8z")]
}
