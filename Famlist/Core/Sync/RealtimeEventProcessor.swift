/*
 RealtimeEventProcessor.swift
 Famlist
 Created on: 22.11.2025
 Last updated on: 22.11.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Processes granular Realtime events from Supabase with CRDT conflict resolution.
 
 🛠 Includes:
 - INSERT, UPDATE, DELETE event processing
 - CRDT-based merge logic for concurrent updates
 - SwiftData integration for local persistence
 
 🔰 Notes for Beginners:
 - Replaces full refetch strategy with granular event processing
 - Each Realtime event is merged with local state using CRDT rules
 - Significantly reduces bandwidth and improves performance
 
 📝 Last Change:
 - Ein Weg für alle Ereignisse (Audit 25.09.2026): SwiftDataItemStore.mergeRemote entscheidet per HLC.
   Keine Sonderregeln mehr für ausstehende Änderungen oder Löschmarkierungen – die neuere HLC gewinnt,
   und Löschmarkierungen bleiben lokal erhalten, damit späte, ältere Updates sie nicht überschreiben.
 ------------------------------------------------------------------------
*/

import Foundation
import SwiftData

/// Processes Realtime events with HLC-based Last-Writer-Wins (ItemSyncPolicy).
final class RealtimeEventProcessor {

    // ISO8601DateFormatter ist teuer in der Erstellung – einmal als static property anlegen.
    private static let isoFormatter = ISO8601DateFormatter()

    // MARK: - Dependencies

    private let itemStore: SwiftDataItemStore

    // MARK: - Initialization

    init(itemStore: SwiftDataItemStore) {
        self.itemStore = itemStore
    }

    // MARK: - Event Processing

    /// INSERT und UPDATE: Zeile per HLC abgleichen. Fehlt `imagedata` im Ereignis (Postgres schickt
    /// unveränderte große Werte bei UPDATE nicht mit), bleibt das lokale Foto erhalten.
    /// - Returns: Ergebnis des Abgleichs (für die Hervorhebung „von anderem Gerät geändert“).
    @MainActor
    @discardableResult
    func processUpsert(_ payload: [String: Any], listId: UUID) -> SwiftDataItemStore.RemoteMergeResult {
        guard let record = payload["record"] as? [String: Any] else {
            logVoid(params: (action: "processUpsert.error", reason: "Missing record in payload"))
            return .ignored
        }
        do {
            let (item, _) = try parseItemFromPayload(record)
            let result = try itemStore.mergeRemote(item, includeImage: record.keys.contains("imagedata"))
            try itemStore.save()
            logVoid(params: (action: "processUpsert", itemId: item.id, result: "\(result)"))
            return result
        } catch {
            logVoid(params: (action: "processUpsert.error", error: error.localizedDescription))
            return .ignored
        }
    }

    /// Kompatibilität für Aufrufer/Tests der alten API.
    @MainActor
    func processInsertion(_ payload: [String: Any], listId: UUID) async { processUpsert(payload, listId: listId) }

    /// Kompatibilität für Aufrufer/Tests der alten API.
    @MainActor
    func processUpdate(_ payload: [String: Any], listId: UUID) async { processUpsert(payload, listId: listId) }

    /// DELETE: Die Zeile ist auf dem Server endgültig weg (Aufräumen nach 30 Tagen oder Liste gelöscht).
    /// Dann gibt es nichts mehr abzugleichen – lokal ebenfalls entfernen.
    @MainActor
    func processDeletion(_ payload: [String: Any], listId: UUID) async {
        guard let oldRecord = payload["old_record"] as? [String: Any],
              let idString = oldRecord["id"] as? String,
              let uuid = UUID(uuidString: idString) else {
            logVoid(params: (action: "processDeletion.error", reason: "Invalid old_record"))
            return
        }
        try? itemStore.purge(id: uuid)
        logVoid(params: (action: "processDeletion.purge", itemId: idString))
    }

    // MARK: - Helpers
    
    private func parseItemFromPayload(_ record: [String: Any]) throws -> (ItemModel, CRDTMetadata) {
        // Helper to extract values from Supabase AnyJSON or plain Any
        func extractString(_ key: String) -> String? {
            if let value = record[key] as? String {
                return value
            }
            // Handle AnyJSON case
            if let anyJSON = record[key], String(describing: anyJSON) != "<null>" {
                let str = String(describing: anyJSON)
                // Remove potential AnyJSON wrapper prefixes
                return str.replacingOccurrences(of: "AnyJSON.", with: "")
            }
            return nil
        }
        
        func extractInt(_ key: String) -> Int? {
            if let value = record[key] as? Int {
                return value
            }
            if let value = record[key] as? Double {
                return Int(value)
            }
            // AnyJSON-Wrapper / Zahl als Text (wie extractDouble): sonst fiel die Menge still auf 1 zurück.
            if let anyValue = record[key], String(describing: anyValue) != "<null>" {
                let str = String(describing: anyValue).replacingOccurrences(of: "AnyJSON.", with: "")
                if let intVal = Int(str) { return intVal }
                if let doubleVal = Double(str) { return Int(doubleVal) }
            }
            return nil
        }
        
        func extractDouble(_ key: String) -> Double? {
            if let value = record[key] as? Double {
                return value
            }
            if let value = record[key] as? Int {
                return Double(value)
            }
            // Handle AnyJSON wrapper: analogous to extractString / extractBool
            if let anyValue = record[key], String(describing: anyValue) != "<null>" {
                let str = String(describing: anyValue).replacingOccurrences(of: "AnyJSON.", with: "")
                if let doubleVal = Double(str) { return doubleVal }
                if let intVal = Int(str) { return Double(intVal) }
            }
            return nil
        }
        
        func extractBool(_ key: String) -> Bool? {
            if let value = record[key] as? Bool {
                return value
            }
            // Handle AnyJSON wrapper: AnyJSON.bool(true) describes as "bool(true)"
            if let anyValue = record[key] {
                let description = String(describing: anyValue)
                    .replacingOccurrences(of: "AnyJSON.", with: "")
                    .lowercased()
                switch description {
                case "true", "bool(true)": return true
                case "false", "bool(false)": return false
                default: return nil
                }
            }
            return nil
        }
        
        guard let idString = extractString("id") else {
            throw NSError(domain: "RealtimeEventProcessor", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "Missing id in record"])
        }
        
        let name = extractString("name") ?? ""
        let units = extractInt("units") ?? 1
        let measure = extractString("measure") ?? ""
        let price = extractDouble("price") ?? 0.0
        let isChecked = extractBool("isChecked") ?? false
        let isUnavailable = extractBool("is_unavailable") ?? false
        let category = extractString("category")
        let productDescription = extractString("productdescription")
        let brand = extractString("brand")
        let imageData = extractString("imagedata")
        
        let listIdString = extractString("list_id")
        let ownerPublicId = extractString("ownerpublicid")
        
        // Parse dates
        let createdAt: Date?
        if let createdAtString = extractString("created_at") {
            createdAt = Self.isoFormatter.date(from:createdAtString)
        } else {
            createdAt = nil
        }
        
        let updatedAt: Date?
        if let updatedAtString = extractString("updated_at") {
            updatedAt = Self.isoFormatter.date(from:updatedAtString)
        } else {
            updatedAt = nil
        }
        
        // Extract CRDT metadata (with fallbacks for backward compatibility)
        func extractInt64(_ key: String) -> Int64? {
            if let value = record[key] as? Int64 {
                return value
            }
            if let value = record[key] as? Int {
                return Int64(value)
            }
            if let value = record[key] as? Double {
                return Int64(value)
            }
            // Zahl als Text (wie extractInt): sonst fiele die HLC auf 0 und die Änderung verlöre jeden Vergleich.
            if let text = record[key] as? String { return Int64(text) }
            return nil
        }
        
        // Fallback of 0 (epoch) ensures a row with null hlc_timestamp always loses to any valid
        // local HLC in CRDT conflict resolution (happenedBefore → remote epoch < local ms ≫ 0).
        // The previous fallback of Int64(Date().timeIntervalSince1970 * 1000) could TIE with or
        // beat the freshly-generated local HLC, causing stale Realtime echoes to overwrite
        // in-flight local changes (e.g. units=3 overwritten back to units=1).
        let hlcTimestamp = extractInt64("hlc_timestamp") ?? 0
        let hlcCounter = extractInt("hlc_counter") ?? 0
        let hlcNodeId = extractString("hlc_node_id") ?? ""
        let tombstone = extractBool("tombstone") ?? false
        let lastModifiedBy = extractString("last_modified_by") ?? ""
        
        let hlc = HybridLogicalClock(
            timestamp: hlcTimestamp,
            counter: hlcCounter,
            nodeId: hlcNodeId
        )
        
        let metadata = CRDTMetadata(
            hlc: hlc,
            tombstone: tombstone,
            lastModifiedBy: lastModifiedBy
        )
        
        let item = ItemModel(
            id: idString,
            imageUrl: nil,
            imageData: imageData,
            name: name,
            units: units,
            measure: measure,
            price: price,
            isChecked: isChecked,
            isUnavailable: isUnavailable,
            category: category,
            productDescription: productDescription,
            brand: brand,
            listId: listIdString,
            ownerPublicId: ownerPublicId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            hlcTimestamp: hlcTimestamp,
            hlcCounter: hlcCounter,
            hlcNodeId: hlcNodeId,
            tombstone: tombstone,
            lastModifiedBy: lastModifiedBy
        )
        
        return (item, metadata)
    }
}
