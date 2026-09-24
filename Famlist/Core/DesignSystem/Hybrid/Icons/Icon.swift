/*
 Icon.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Icon-Katalog: alle Icons als Original-Vektorpfade aus dem Design.

 🔰 Notes for Beginners:
 - Teil des Hybrid-Designs (Canvas „My List – Redesign“). Übersetzt CSS-Werte 1:1 nach SwiftUI.
   Umrechnungsregeln: siehe Core/DesignSystem/Hybrid/README.md.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

enum Icon {
    static let chevronDown: [SVGElement] = [.path("M6 9l6 6 6-6")]
    static let chevronRight: [SVGElement] = [.path("M9 6l6 6-6 6")]
    static let chevronsUpDown: [SVGElement] = [.path("M8 9l4-4 4 4M8 15l4 4 4-4")]
    static let viewToggle: [SVGElement] = [.rect(3.5, 4, 17, 7, 2), .path("M4 15.5h16M4 19.5h16")]
    static let menu: [SVGElement] = [.path("M5 8h14M5 12h14M5 16h14")]
    static let search: [SVGElement] = [.circle(11, 11, 6.5), .path("M16 16l4 4")]
    static let scan: [SVGElement] = [.path("M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2M8 9v6M11 9v6M14 9v6M17 9v6")]
    static let basket: [SVGElement] = [.path("M3 10h18l-1.6 8.2a2 2 0 0 1-2 1.8H6.6a2 2 0 0 1-2-1.8L3 10z"),
                                       .path("M8 10l3-6M16 10l-3-6M9 14v3M12 14v3M15 14v3")]
    static let check: [SVGElement] = [.path("M5 12.5l4.5 4.5L19 7.5")]
    static let tag: [SVGElement] = [.path("M20.6 13.4 13.4 20.6a2 2 0 0 1-2.8 0L3 13V3h10l7.6 7.6a2 2 0 0 1 0 2.8z"),
                                    .circle(8, 8, 1.4)]
    static let cameraOff: [SVGElement] = [.path("M3 3l18 18"),
                                          .path("M9.5 5h5l1.5 2H19a2 2 0 0 1 2 2v8.5M17 19H5a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2h2"),
                                          .path("M9.9 10.2a3 3 0 0 0 4 4")]
    static let camera: [SVGElement] = [.path("M4 8a2 2 0 0 1 2-2h2l1.5-2h5L16 6h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8z"),
                                       .circle(12, 12.5, 3.5)]
    static let undo: [SVGElement] = [.path("M9 14L4 9l5-5"), .path("M4 9h10.5a5.5 5.5 0 0 1 0 11H11")]
    static let listBullets: [SVGElement] = [.path("M9 7h11M9 12h11M9 17h11"),
                                            .circle(5, 7, 1), .circle(5, 12, 1), .circle(5, 17, 1)]
    static let star: [SVGElement] = [.path("M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8-4.3-4.1 5.9-.9L12 3.5z")]
    static let trashAction: [SVGElement] = [.path("M4 7h16M9.5 7V4.8h5V7M6.5 7l.9 11.2a2 2 0 0 0 2 1.8h5.2a2 2 0 0 0 2-1.8L17.5 7")]
    static let pencil: [SVGElement] = [.path("M4 20h4L19 9a2.8 2.8 0 0 0-4-4L4 16v4zM13.5 6.5l4 4")]
    static let unavailable: [SVGElement] = [.path("M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM8 12h8")]
    static let listCheck: [SVGElement] = [.path("M9 6h11M9 12h11M9 18h11"), .path("M4 6l1 1 1.8-2M4 12l1 1 1.8-2"),
                                          .circle(5, 18, 1)]
    static let sort: [SVGElement] = [.path("M8 19V5M4.5 8.5 8 5l3.5 3.5M16 5v14M12.5 15.5 16 19l3.5-3.5")]
    static let duplicate: [SVGElement] = [.rect(8, 8, 12, 12, 3),
                                          .path("M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2")]
    static let trash: [SVGElement] = [.path("M4 7h16M9.5 7V4.8h5V7M6.5 7l.9 11.2a2 2 0 0 0 2 1.8h5.2a2 2 0 0 0 2-1.8L17.5 7M10 11v5M14 11v5")]
    static let plus: [SVGElement] = [.path("M12 5v14M5 12h14")]
    static let minus: [SVGElement] = [.path("M5 12h14")]
    static let close: [SVGElement] = [.path("M6 6l12 12M18 6L6 18")]
    static let cart: [SVGElement] = [.path("M3 4h2.5l2 11h10.5l2-8H7"), .circle(9.5, 19, 1.2), .circle(16.5, 19, 1.2)]
    static let leaf: [SVGElement] = [.path("M5 19c0-8 5-14 14-14 0 9-6 14-14 14zM5 19l8-8")]
    static let drop: [SVGElement] = [.path("M12 3.5s-6 6.6-6 10.5a6 6 0 0 0 12 0c0-3.9-6-10.5-6-10.5z")]
    static let cutlery: [SVGElement] = [.path("M7 3v8M5 3v5a2 2 0 0 0 4 0V3M7 11v10M16 21V3c-2 1.5-3 4-3 7h3")]

    // MARK: Ergänzungen für Famlist (nicht im Design-Canvas, im selben Stil gezeichnet)
    // Kategorien ohne Design-Icon sowie „Wieder verfügbar“.
    static let glass: [SVGElement] = [.path("M7 4h10l-1.2 14.4a2 2 0 0 1-2 1.6h-3.6a2 2 0 0 1-2-1.6L7 4zM7.5 9h9")]
    static let home: [SVGElement] = [.path("M4 11.5 12 5l8 6.5M6.5 9.8V19a1 1 0 0 0 1 1h9a1 1 0 0 0 1-1V9.8M10 20v-5h4v5")]
    static let snowflake: [SVGElement] = [.path("M12 3v18M4.2 7.5l15.6 9M4.2 16.5l15.6-9M9.5 4.5 12 7l2.5-2.5M9.5 19.5 12 17l2.5 2.5")]
    static let flame: [SVGElement] = [.path("M12 3c.5 3 4 5 4 9.5a4 4 0 0 1-8 0c0-2 1-3.5 2-4.5 0 1.5.8 2.5 2 3 0-3-1-5.5 0-8z")]
    static let restore: [SVGElement] = [.path("M4 12a8 8 0 1 0 2.3-5.7M4 4v4h4")]
}
