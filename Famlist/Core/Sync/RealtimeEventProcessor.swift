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
 - Initial implementation for CRDT-based sync architecture
 ------------------------------------------------------------------------
*/

import Foundation
import SwiftData

/// Processes Realtime events with CRDT-based conflict resolution
final class RealtimeEventProcessor {
    
    // MARK: - Dependencies
    
    private let conflictResolver: ConflictResolver
    private let itemStore: SwiftDataItemStore
    
    // MARK: - Initialization
    
    init(conflictResolver: ConflictResolver, itemStore: SwiftDataItemStore) {
        self.conflictResolver = conflictResolver
        self.itemStore = itemStore
    }
    
    // MARK: - Event Processing
    
    /// Processes an INSERT event from Realtime
    /// - Parameters:
    ///   - payload: Raw payload from Supabase Realtime
    ///   - listId: UUID of the list being observed
    @MainActor
    func processInsertion(_ payload: [String: Any], listId: UUID) async {
        do {
            guard let record = payload["record"] as? [String: Any] else {
                logVoid(params: (
                    action: "processInsertion.error",
                    reason: "Missing record in payload"
                ))
                return
            }
            
            let (item, metadata) = try parseItemFromPayload(record)
            
            // Check if we already have this item locally
            guard let uuid = UUID(uuidString: item.id) else { return }
            
            if let existingEntity = try? itemStore.fetchItem(id: uuid) {
                // Item exists locally - resolve conflict
                let existingMetadata = extractMetadataFromEntity(existingEntity)
                
                if conflictResolver.shouldApplyRemote(localMeta: existingMetadata, remoteMeta: metadata) {
                    applyToEntity(existingEntity, item: item, metadata: metadata)
                    try? itemStore.save()
                    
                    logVoid(params: (
                        action: "processInsertion.merge",
                        itemId: item.id,
                        decision: "remote_wins"
                    ))
                } else {
                    logVoid(params: (
                        action: "processInsertion.merge",
                        itemId: item.id,
                        decision: "local_wins"
                    ))
                }
            } else {
                // New item - insert locally
                let entity = try itemStore.upsert(model: item)
                applyMetadataToEntity(entity, metadata: metadata)
                entity.setSyncStatus(.synced)
                try itemStore.save()
                
                logVoid(params: (
                    action: "processInsertion.insert",
                    itemId: item.id
                ))
            }
        } catch {
            logVoid(params: (
                action: "processInsertion.error",
                error: error.localizedDescription
            ))
        }
    }
    
    /// Processes an UPDATE event from Realtime
    /// - Parameters:
    ///   - payload: Raw payload from Supabase Realtime
    ///   - listId: UUID of the list being observed
    @MainActor
    func processUpdate(_ payload: [String: Any], listId: UUID) async {
        do {
            guard let record = payload["record"] as? [String: Any] else {
                logVoid(params: (
                    action: "processUpdate.error",
                    reason: "Missing record in payload"
                ))
                return
            }
            
            let (item, metadata) = try parseItemFromPayload(record)
            
            guard let uuid = UUID(uuidString: item.id) else { return }
            
            if let existingEntity = try? itemStore.fetchItem(id: uuid) {
                let existingMetadata = extractMetadataFromEntity(existingEntity)
                
                // Use CRDT conflict resolution
                if conflictResolver.shouldApplyRemote(localMeta: existingMetadata, remoteMeta: metadata) {
                    applyToEntity(existingEntity, item: item, metadata: metadata)
                    
                    // Only mark as synced if we don't have pending local changes
                    if existingEntity.syncStatus == .synced {
                        existingEntity.setSyncStatus(.synced)
                    }
                    
                    try itemStore.save()
                    
                    logVoid(params: (
                        action: "processUpdate.merge",
                        itemId: item.id,
                        decision: "remote_wins"
                    ))
                    
                    UserLog.Sync.realtimeUpdateReceived(name: item.name)
                } else {
                    logVoid(params: (
                        action: "processUpdate.merge",
                        itemId: item.id,
                        decision: "local_wins"
                    ))
                }
            } else {
                // Item doesn't exist locally - treat as insert
                let entity = try itemStore.upsert(model: item)
                applyMetadataToEntity(entity, metadata: metadata)
                entity.setSyncStatus(.synced)
                try itemStore.save()
                
                logVoid(params: (
                    action: "processUpdate.insertMissing",
                    itemId: item.id
                ))
            }
        } catch {
            logVoid(params: (
                action: "processUpdate.error",
                error: error.localizedDescription
            ))
        }
    }
    
    /// Processes a DELETE event from Realtime
    /// - Parameters:
    ///   - payload: Raw payload from Supabase Realtime
    ///   - listId: UUID of the list being observed
    @MainActor
    func processDeletion(_ payload: [String: Any], listId: UUID) async {
        guard let oldRecord = payload["old_record"] as? [String: Any] else {
            logVoid(params: (
                action: "processDeletion.error",
                reason: "Missing old_record in payload"
            ))
            return
        }
        
        func extractString(_ key: String, from dict: [String: Any]) -> String? {
            if let value = dict[key] as? String {
                return value
            }
            // Handle AnyJSON case
            if let anyJSON = dict[key], String(describing: anyJSON) != "<null>" {
                let str = String(describing: anyJSON)
                return str.replacingOccurrences(of: "AnyJSON.", with: "")
            }
            return nil
        }
        
        guard let idString = extractString("id", from: oldRecord),
              let uuid = UUID(uuidString: idString) else {
            logVoid(params: (
                action: "processDeletion.error",
                reason: "Invalid id in payload"
            ))
            return
        }
        
        // Check if we have a pending local operation for this item
        var itemName: String?
        if let existingEntity = try? itemStore.fetchItem(id: uuid) {
            itemName = existingEntity.name // Speichere Namen für User-Log
            if existingEntity.syncStatus == .pendingCreate ||
               existingEntity.syncStatus == .pendingUpdate {
                // We have local changes - don't delete yet, let sync engine handle it
                logVoid(params: (
                    action: "processDeletion.skip",
                    itemId: idString,
                    reason: "pending_local_changes"
                ))
                return
            }
        }
        
        // Safe to delete locally
        try? itemStore.purge(id: uuid)
        
        logVoid(params: (
            action: "processDeletion.purge",
            itemId: idString
        ))
        
        UserLog.Sync.realtimeDeleteReceived(name: itemName)
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
            return nil
        }
        
        func extractDouble(_ key: String) -> Double? {
            if let value = record[key] as? Double {
                return value
            }
            if let value = record[key] as? Int {
                return Double(value)
            }
            return nil
        }
        
        func extractBool(_ key: String) -> Bool? {
            if let value = record[key] as? Bool {
                return value
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
        let category = extractString("category")
        let productDescription = extractString("productdescription")
        let brand = extractString("brand")
        let imageData = extractString("imagedata")
        
        let listIdString = extractString("list_id")
        let ownerPublicId = extractString("ownerpublicid")
        
        // Parse dates
        let createdAt: Date?
        if let createdAtString = extractString("created_at") {
            createdAt = ISO8601DateFormatter().date(from: createdAtString)
        } else {
            createdAt = nil
        }
        
        let updatedAt: Date?
        if let updatedAtString = extractString("updated_at") {
            updatedAt = ISO8601DateFormatter().date(from: updatedAtString)
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
            return nil
        }
        
        let hlcTimestamp = extractInt64("hlc_timestamp") ?? Int64(Date().timeIntervalSince1970 * 1000)
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
    
    private func extractMetadataFromEntity(_ entity: ItemEntity) -> CRDTMetadata {
        // Initialize CRDT fields if they're missing (for old data)
        let timestamp = entity.hlcTimestamp ?? Int64(Date().timeIntervalSince1970 * 1000)
        let counter = entity.hlcCounter ?? 0
        let nodeId = entity.hlcNodeId ?? ""
        
        let hlc = HybridLogicalClock(
            timestamp: timestamp,
            counter: counter,
            nodeId: nodeId
        )
        
        return CRDTMetadata(
            hlc: hlc,
            tombstone: entity.tombstone ?? false,
            lastModifiedBy: entity.lastModifiedBy ?? ""
        )
    }
    
    private func applyToEntity(_ entity: ItemEntity, item: ItemModel, metadata: CRDTMetadata) {
        // Apply item data
        entity.apply(model: item)
        
        // Apply CRDT metadata
        applyMetadataToEntity(entity, metadata: metadata)
    }
    
    private func applyMetadataToEntity(_ entity: ItemEntity, metadata: CRDTMetadata) {
        entity.hlcTimestamp = metadata.hlc.timestamp
        entity.hlcCounter = metadata.hlc.counter
        entity.hlcNodeId = metadata.hlc.nodeId
        entity.tombstone = metadata.tombstone
        entity.lastModifiedBy = metadata.lastModifiedBy
    }
}


