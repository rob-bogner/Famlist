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
        do {
            guard let oldRecord = payload["old_record"] as? [String: Any] else {
                logVoid(params: (
                    action: "processDeletion.error",
                    reason: "Missing old_record in payload"
                ))
                return
            }
            
            guard let idString = oldRecord["id"] as? String,
                  let uuid = UUID(uuidString: idString) else {
                logVoid(params: (
                    action: "processDeletion.error",
                    reason: "Invalid id in payload"
                ))
                return
            }
            
            // Check if we have a pending local operation for this item
            if let existingEntity = try? itemStore.fetchItem(id: uuid) {
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
        } catch {
            logVoid(params: (
                action: "processDeletion.error",
                error: error.localizedDescription
            ))
        }
    }
    
    // MARK: - Helpers
    
    private func parseItemFromPayload(_ record: [String: Any]) throws -> (ItemModel, CRDTMetadata) {
        // Extract values directly from dictionary instead of JSON serialization
        // to avoid issues with non-JSON-serializable Swift types
        
        guard let idString = record["id"] as? String else {
            throw NSError(domain: "RealtimeEventProcessor", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "Missing id in record"])
        }
        
        let name = record["name"] as? String ?? ""
        let units = record["units"] as? Int ?? 1
        let measure = record["measure"] as? String ?? ""
        let price = record["price"] as? Double ?? 0.0
        let isChecked = record["isChecked"] as? Bool ?? false
        let category = record["category"] as? String
        let productDescription = record["productdescription"] as? String
        let brand = record["brand"] as? String
        let imageData = record["imagedata"] as? String
        
        let listIdString = record["list_id"] as? String
        let ownerPublicId = record["ownerpublicid"] as? String
        
        // Parse dates
        let createdAt: Date?
        if let createdAtString = record["created_at"] as? String {
            createdAt = ISO8601DateFormatter().date(from: createdAtString)
        } else {
            createdAt = nil
        }
        
        let updatedAt: Date?
        if let updatedAtString = record["updated_at"] as? String {
            updatedAt = ISO8601DateFormatter().date(from: updatedAtString)
        } else {
            updatedAt = nil
        }
        
        // Extract CRDT metadata (with fallbacks for backward compatibility)
        let hlcTimestamp = record["hlc_timestamp"] as? Int64 ?? Int64(Date().timeIntervalSince1970 * 1000)
        let hlcCounter = record["hlc_counter"] as? Int ?? 0
        let hlcNodeId = record["hlc_node_id"] as? String ?? ""
        let tombstone = record["tombstone"] as? Bool ?? false
        let lastModifiedBy = record["last_modified_by"] as? String ?? ""
        
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

