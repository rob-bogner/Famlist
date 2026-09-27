/*
 RestoreAccountIcon.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Original-SVG-Pfade des Screens „Konto wiederherstellen“ (RestoreAccount.dc.html) und des Hinweises
   „Mitglied hat sein Konto gelöscht“ (MemberDeletedToast.dc.html, ShareMembers.dc.html).

 🔰 Notes for Beginners:
 - Pfade 1:1 aus den Boards (viewBox 24 × 24), gezeichnet mit SVGIcon. Keine SF Symbols.

 📝 Last Change:
 - Initial creation (Konto-Archiv, Phase 3).
 ------------------------------------------------------------------------
 */

import SwiftUI

enum RestoreAccountIcon {
    /// Kreispfeil mit Person (Kopf-Kachel)
    static let restore: [SVGElement] = [.path("M3.5 12a8.5 8.5 0 1 0 2.5-6"), .path("M3.5 3.5V8H8"),
                                        .circle(12, 10.5, 2.4), .path("M8 17c.8-2 2.2-3 4-3s3.2 1 4 3")]
    /// Uhr im Chip „Noch 60 Tage“
    static let clock: [SVGElement] = [.circle(12, 12, 9), .path("M12 7v5l3 2")]
    /// Listen und Artikel
    static let lists: [SVGElement] = [.path("M9 6h11M9 12h11M9 18h11"),
                                      .path("M4 6l1 1 1.8-2M4 12l1 1 1.8-2M4 18l1 1 1.8-2")]
    /// Fotos
    static let photos: [SVGElement] = [.rect(3, 5, 18, 14, 3), .path("M3 16l5-5 4 4 3-3 6 6"), .circle(16, 9.5, 1.5)]
    /// Geteilte Listen samt Mitgliedern
    static let members: [SVGElement] = [.circle(9, 8.5, 3), .path("M3.5 19c.7-3 2.8-4.6 5.5-4.6s4.8 1.6 5.5 4.6"),
                                        .circle(17, 9.5, 2.4), .path("M16.5 14.6c2.2.1 3.6 1.5 4.1 4")]
    /// Listen anderer (Pfeil hinein)
    static let enter: [SVGElement] = [.path("M4 12h11M11 8l4 4-4 4"), .path("M14 4h4a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-4")]
    /// Person mit Minus (MemberDeletedToast)
    static let memberLeft: [SVGElement] = [.circle(10, 8.5, 3.4), .path("M3.5 19.5c.8-3.3 3.3-5.1 6.5-5.1 1.4 0 2.6.3 3.6.9"),
                                           .path("M16 17h6")]
    /// Offline-Hinweis
    static let offline: [SVGElement] = [.path("M2 8.5a15 15 0 0 1 4.3-2.7M9.5 5.1A15 15 0 0 1 22 8.5M5 12a10 10 0 0 1 3.3-2M13.5 9.6A10 10 0 0 1 19 12M8.5 15.5a5 5 0 0 1 6.2-.6M12 19.5h.01M3 3l18 18")]
}
