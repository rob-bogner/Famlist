/*
 ReceiptMetaIcon.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Icons der Einkaufsdaten und der Auswertung als Original-Pfade aus den Boards
   (ReceiptDetailMeta.dc.html, ReceiptArchiveInsights.dc.html, InsightSpend.dc.html, InsightUsage.dc.html).

 🔰 Notes for Beginners:
 - Keine SF Symbols (Designregel); gezeichnet über SVGIcon.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

enum ReceiptMetaIcon {
    static let store: [SVGElement] = [.path("M4 9l1.5-5h13L20 9M4 9v11h16V9M4 9h16M9 20v-6h6v6")]
    static let calendar: [SVGElement] = [.path("M4 6h16v14H4zM4 10h16M8 3v4M16 3v4")]
    static let clock: [SVGElement] = [.path("M12 3a9 9 0 1 0 0 18 9 9 0 1 0 0-18M12 7v5l3 2")]
    static let stopwatch: [SVGElement] = [.path("M12 5a8 8 0 1 0 0 16 8 8 0 1 0 0-16M12 9v4M9.5 2h5M18.5 6.5l1.5-1.5")]
    static let bag: [SVGElement] = [.path("M5 8h14l-1 12H6zM9 8V6a3 3 0 0 1 6 0v2")]
    static let euro: [SVGElement] = [.path("M17 6.5A7 7 0 1 0 17 17.5M4 10h9M4 14h9")]
}
