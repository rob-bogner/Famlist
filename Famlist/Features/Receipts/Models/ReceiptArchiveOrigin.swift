/*
 ReceiptArchiveOrigin.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Wo und von wem ein Kassenzettel gescannt wurde: Liste, auf der eingekauft wurde, und die Person.

 🔰 Notes for Beginners:
 - Der Kassenzettel-Ablauf kennt die Liste nicht; ShoppingListView gibt sie beim Start mit.
 - Auf dem Server bestimmt die Sitzung `created_by`; `createdBy`/`creatorName` dienen nur der Anzeige,
   solange der Bon noch nicht hochgeladen ist.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import Foundation

struct ReceiptArchiveOrigin: Equatable {
    var listId: UUID
    var listTitle: String?
    var createdBy: UUID?
    var creatorName: String?
}
