/*
 ReceiptPage.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Eine Aufnahme im Ablauf „Kassenzettel“: das Originalfoto, die erkannten Ecken und das Bild,
   das angezeigt, gelesen und archiviert wird.

 🔰 Notes for Beginners:
 - Direkt nach der Aufnahme ist `image` noch das Originalfoto. Sobald der Zuschnitt fertig ist,
   ersetzt ihn der gerade gezogene Bon (`isCropping` wird false).
 - Das Original bleibt nur während des Ablaufs im Speicher: Daraus lassen sich die Ecken später neu setzen.
   Ins Archiv kommt nur `image`.

 📝 Last Change:
 - Initial creation (automatischer Bon-Zuschnitt).
 ------------------------------------------------------------------------
 */

import UIKit

struct ReceiptPage: Identifiable {
    let id: UUID
    let original: UIImage
    var quad: ReceiptQuad?
    var image: UIImage
    var isCropping: Bool

    init(id: UUID = UUID(), original: UIImage) {
        self.id = id
        self.original = original
        self.quad = nil
        self.image = original
        self.isCropping = true
    }
}
