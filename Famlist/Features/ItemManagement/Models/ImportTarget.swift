/*
 ImportTarget.swift
 Famlist
 Created on: 17.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Schreibart eines Import-Artikels (neu, reaktivieren, aktualisieren) für SyncEngine.applyBulkItems.

 📝 Last Change:
 - Aus ImportMergeService.swift ausgelagert; wird auch vom Watch-Target mitkompiliert (26.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

/// Describes the write operation required for one canonical import item.
enum ImportTarget {
    /// ID not present in the local store → create a new entity.
    case createNew(ItemModel)
    /// ID present but soft-deleted (`deletedAt != nil`) → reactivate the entity
    /// with fresh imported data. `units` = importedUnits (NOT old + imported).
    case reactivate(ItemModel)
    /// ID present and active → increment `units` by the imported amount.
    case update(ItemModel)

    /// The merged ItemModel for this target.
    var item: ItemModel {
        switch self {
        case .createNew(let m), .reactivate(let m), .update(let m): return m
        }
    }
}
