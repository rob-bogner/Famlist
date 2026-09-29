/*
 Icon+ActionCard.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zusätzliche Icons für die Aktionskarten (Pfade 1:1 aus den Canvas-Boards, 24 × 24, Strich 2).

 🔰 Notes for Beginners:
 - Kamera, Etikett, Mülleimer, Plus/Minus und Haken kommen aus Icon.swift.

 📝 Last Change:
 - Initial creation (Designsprache statt Systemdialoge).
 ------------------------------------------------------------------------
 */

import SwiftUI

extension Icon {
    /// Zwei Kreispfeile (Sync fehlgeschlagen, „Erneut synchronisieren“).
    static let sync: [SVGElement] = [.path("M20 11a8 8 0 0 0-14.3-4.9L4 8M4 4v4h4M4 13a8 8 0 0 0 14.3 4.9L20 16M20 20v-4h-4")]
    /// Tür mit Pfeil (Abmelden).
    static let logout: [SVGElement] = [.path("M14 4h4a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-4M10 16l-4-4 4-4M6 12h10")]
    /// Laden (Laden ändern).
    static let store: [SVGElement] = [.path("M4 9l1.5-5h13L20 9M4 9v11h16V9M4 9h16M9 20v-6h6v6")]
    /// Kassenbon mit Zackenrand.
    static let receipt: [SVGElement] = [.path("M6 3h12v18l-2-1.4-2 1.4-2-1.4-2 1.4-2-1.4L6 21zM9 8h6M9 12h6M9 16h3")]
    /// Person mit Kreuz (Mitglied entfernen).
    static let userRemove: [SVGElement] = [.path("M12.5 8a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0zM2.5 19c1-3 3.5-4.5 6.5-4.5s5.5 1.5 6.5 4.5M16 10l5 5M21 10l-5 5")]
    /// Bild (Aus Mediathek).
    static let image: [SVGElement] = [.path("M4 5h16v14H4zM4 16l5-5 4 4 2-2 5 5M15.5 9.5a1.5 1.5 0 1 0 0-.01")]
    /// Kettenglied (Bon-Zeile zuordnen).
    static let link: [SVGElement] = [.path("M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1")]
    /// Drei Winkel nach rechts (Hinweis „Schieben zum Löschen“).
    static let chevronsRight: [SVGElement] = [.path("M4 7l5 5-5 5M10 7l5 5-5 5M16 7l5 5-5 5")]
    /// Pfeil nach rechts (Auswahl-Zeile, Preis alt → neu).
    static let arrowRight: [SVGElement] = [.path("M5 12h14M13 6l6 6-6 6")]
}
