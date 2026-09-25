/*
 XCUIApplication+TestAccounts.swift
 FamlistUITests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Öffnet im Anmeldebildschirm den Dialog „Testkonten (nur Simulator)“ per langem Druck auf die Korb-Kachel.

 🔰 Notes for Beginners:
 - Die Kachel ist vor VoiceOver verborgen und deshalb kein abfragbares Element. Sie liegt laut SignInView
   86 × 86 pt groß, bündig links, 18 pt über dem Titel „Famlist“. Die Position wird daraus berechnet –
   eine feste Koordinate passte nach dem fließenden Layout nur noch auf einem Gerät (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import XCTest

extension XCUIApplication {
    /// Langer Druck auf die Korb-Kachel; gibt false zurück, wenn der Titel nicht gefunden wurde.
    @discardableResult
    func openTestAccountsDialog() -> Bool {
        let title = staticTexts["Famlist"]
        guard title.waitForExistence(timeout: 10) else { return false }
        let frame = title.frame
        let tileCenter = CGVector(dx: frame.minX + 43, dy: frame.minY - 18 - 43)
        coordinate(withNormalizedOffset: .zero).withOffset(tileCenter).press(forDuration: 1.2)
        return true
    }
}
