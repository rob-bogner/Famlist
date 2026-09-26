/*
 ReceiptMissingResolution.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Entscheidung für einen abgehakten Artikel, der auf dem Kassenzettel nicht gefunden wurde.

 🔰 Notes for Beginners:
 - „Zuordnen“ braucht keinen eigenen Fall: Die Bon-Zeile bekommt den Artikel, damit gilt er als gefunden.
 - `priced`: Preis von Hand eingegeben → wird wie ein Bon-Preis gespeichert.
 - `notBought`: nicht gekauft → der Artikel ist wieder offen auf der Liste, es wird kein Preis gespeichert.
 - Keine Entscheidung (kein Eintrag) → beim Speichern übersprungen.

 📝 Last Change:
 - Initial creation („Nicht auf dem Bon gefunden“, Variante A).
 ------------------------------------------------------------------------
 */

import Foundation

enum ReceiptMissingResolution: Equatable {
    case priced(Decimal)
    case notBought
}
