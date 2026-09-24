/*
 ImportMergeService.swift
 Famlist
 Created on: 17.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Pure merge logic for clipboard import: deduplicates selected ParsedItems,
   sums compatible units, and classifies each canonical item against the
   local SwiftData store (createNew / reactivate / update).

 🛠 Includes:
 - ImportTarget: three-case enum describing the required write operation.
 - ImportMergeService.merge(): stateless, fully unit-testable.

 🔰 Notes for Beginners:
 - No ViewModel or SyncEngine dependency — pass in [ItemModel] from the caller.
 - allLocalItems MUST include soft-deleted items (fetchItems includeDeleted: true)
   so reactivation decisions are correct.

 📝 Last Change:
 - Initial creation (FAM-XX): Bulk-Import Merge Refactor.
 ------------------------------------------------------------------------
 */

import Foundation

// MARK: - ImportTarget

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

// MARK: - ImportMergeService

/// Stateless merge engine for clipboard import.
///
/// Invariant: exactly one `ImportTarget` per canonical `(listId, normalizedName)` pair.
struct ImportMergeService {

    // MARK: - MergeResult

    struct MergeResult {
        /// One decision per canonical item, in order of first occurrence among selected items.
        let targets: [ImportTarget]
    }

    // MARK: - merge()

    /// Merges selected parsed items against the current local store state.
    ///
    /// - Parameters:
    ///   - selected: The user-selected `ParsedItem`s from the clipboard parser.
    ///   - allLocalItems: ALL items for the list, including soft-deleted ones
    ///     (`fetchItems(listId:includeDeleted: true)`). Used to classify targets.
    ///   - listId: The owning list UUID.
    /// - Returns: `MergeResult` with one `ImportTarget` per canonical item.
    static func merge(
        selected: [ClipboardImportParser.ParsedItem],
        allLocalItems: [ItemModel],
        listId: UUID
    ) -> MergeResult {
        guard !selected.isEmpty else { return MergeResult(targets: []) }

        // Build lookup: canonicalId → existing ItemModel (incl. soft-deleted)
        let localByID: [String: ItemModel] = Dictionary(
            allLocalItems.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // Step 1 — Group by canonical ID, preserving first-occurrence order
        var orderedIds: [String] = []
        var groups: [String: [ClipboardImportParser.ParsedItem]] = [:]

        for parsed in selected {
            let canonicalId = parsed.stableId(forList: listId)
            if groups[canonicalId] == nil {
                orderedIds.append(canonicalId)
                groups[canonicalId] = []
            }
            groups[canonicalId]!.append(parsed)
        }

        // Step 2 & 3 — Merge units and classify
        var targets: [ImportTarget] = []

        for canonicalId in orderedIds {
            let group = groups[canonicalId]!
            let first = group[0]

            // Measure compatibility: collect distinct non-empty canonical measure values
            let nonEmptyMeasures = group.map(\.measure).filter { !$0.isEmpty }
            let uniqueNonEmptyMeasures = Set(nonEmptyMeasures)
            let allCompatible = uniqueNonEmptyMeasures.count <= 1

            let finalUnits: Int
            let finalMeasure: String

            if allCompatible {
                // Sum all units; use first non-empty measure (or "" if none)
                finalUnits = group.reduce(0) { $0 + $1.units }
                finalMeasure = nonEmptyMeasures.first ?? ""
            } else {
                // Incompatible measures → use first item only, discard rest
                finalUnits = first.units
                finalMeasure = first.measure
            }

            // First non-nil wins for metadata fields
            let category         = group.compactMap(\.category).first
            let brand            = group.compactMap(\.brand).first
            let productDesc      = group.compactMap(\.productDescription).first

            // Step 3 — Classify against local store
            if let existing = localByID[canonicalId] {
                if existing.deletedAt != nil {
                    // Soft-deleted → reactivate with fresh imported data
                    let reactivatedItem = ItemModel(
                        id: canonicalId,
                        name: first.name,
                        units: finalUnits,
                        measure: finalMeasure,
                        category: category ?? existing.category,
                        productDescription: productDesc ?? existing.productDescription,
                        brand: brand ?? existing.brand,
                        listId: listId.uuidString,
                        ownerPublicId: existing.ownerPublicId
                    )
                    targets.append(.reactivate(reactivatedItem))
                } else {
                    // Active item → accumulate units, preserve existing metadata
                    var updatedItem = existing
                    updatedItem.units = existing.units + finalUnits
                    if !finalMeasure.isEmpty { updatedItem.measure = finalMeasure }
                    if let cat = category   { updatedItem.category = cat }
                    if let desc = productDesc { updatedItem.productDescription = desc }
                    if let br = brand        { updatedItem.brand = br }
                    targets.append(.update(updatedItem))
                }
            } else {
                // Not found → create new
                let newItem = ItemModel(
                    id: canonicalId,
                    name: first.name,
                    units: finalUnits,
                    measure: finalMeasure,
                    category: category,
                    productDescription: productDesc,
                    brand: brand,
                    listId: listId.uuidString
                )
                targets.append(.createNew(newItem))
            }
        }

        return MergeResult(targets: targets)
    }
}
