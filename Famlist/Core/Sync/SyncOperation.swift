/*
 SyncOperation.swift
 Famlist
 Created on: 22.11.2025
 Last updated on: 22.11.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Represents a pending sync operation that needs to be sent to Supabase.
 
 🛠 Includes:
 - SyncOperationType enum (create, update, delete)
 - SyncOperation struct with retry state
 - SwiftData entity for persistent queue
 
 🔰 Notes for Beginners:
 - Operations are queued when offline or when network calls fail
 - Retry logic uses exponential backoff
 - Operations persist across app restarts via SwiftData
 
 📝 Last Change:
 - Initial implementation for CRDT-based sync architecture
 ------------------------------------------------------------------------
*/

import Foundation
import SwiftData

/// Type of sync operation to perform
enum SyncOperationType: String, Codable {
    case create
    case update
    case delete
}

/// Represents a pending synchronization operation
@Model
final class SyncOperation: Identifiable {
    /// Unique identifier for this operation
    @Attribute(.unique) var id: UUID
    
    /// Type of operation (create, update, delete)
    private var typeRawValue: String
    
    /// ID of the item this operation affects
    var itemId: String
    
    /// ID of the list this item belongs to
    var listId: UUID
    
    /// JSON-encoded snapshot of the item at the time of operation
    var itemSnapshotJSON: Data
    
    /// JSON-encoded CRDT metadata
    var crdtMetadataJSON: Data
    
    /// Number of times this operation has been retried
    var retryCount: Int
    
    /// Timestamp when this operation should be retried next (nil = retry immediately)
    var nextRetryAt: Date?
    
    /// Timestamp when this operation was created
    var createdAt: Date
    
    /// Timestamp when this operation was last attempted
    var lastAttemptAt: Date?
    
    /// Whether this operation has permanently failed (exceeded max retries)
    var hasFailed: Bool
    
    /// Error message from last failure (for debugging)
    var lastErrorMessage: String?
    
    // MARK: - Computed Properties
    
    /// Type of operation (decoded from raw value)
    var type: SyncOperationType {
        get { SyncOperationType(rawValue: typeRawValue) ?? .update }
        set { typeRawValue = newValue.rawValue }
    }
    
    /// Whether this operation is ready to be retried
    var isReadyForRetry: Bool {
        guard !hasFailed else { return false }
        guard let nextRetry = nextRetryAt else { return true }
        return Date() >= nextRetry
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        type: SyncOperationType,
        itemId: String,
        listId: UUID,
        itemSnapshotJSON: Data,
        crdtMetadataJSON: Data,
        retryCount: Int = 0,
        nextRetryAt: Date? = nil,
        createdAt: Date = Date(),
        lastAttemptAt: Date? = nil,
        hasFailed: Bool = false,
        lastErrorMessage: String? = nil
    ) {
        self.id = id
        self.typeRawValue = type.rawValue
        self.itemId = itemId
        self.listId = listId
        self.itemSnapshotJSON = itemSnapshotJSON
        self.crdtMetadataJSON = crdtMetadataJSON
        self.retryCount = retryCount
        self.nextRetryAt = nextRetryAt
        self.createdAt = createdAt
        self.lastAttemptAt = lastAttemptAt
        self.hasFailed = hasFailed
        self.lastErrorMessage = lastErrorMessage
    }
    
    // MARK: - Helpers
    
    /// Decodes the item snapshot from JSON
    func decodeItemSnapshot() throws -> ItemModel {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ItemModel.self, from: itemSnapshotJSON)
    }
    
    /// Decodes the CRDT metadata from JSON
    func decodeCRDTMetadata() throws -> CRDTMetadata {
        let decoder = JSONDecoder()
        return try decoder.decode(CRDTMetadata.self, from: crdtMetadataJSON)
    }
    
    /// Creates a new SyncOperation from ItemModel and metadata
    static func create(
        type: SyncOperationType,
        item: ItemModel,
        metadata: CRDTMetadata
    ) throws -> SyncOperation {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let itemJSON = try encoder.encode(item)
        let metadataJSON = try encoder.encode(metadata)
        
        guard let listIdString = item.listId,
              let listUUID = UUID(uuidString: listIdString) else {
            throw NSError(
                domain: "SyncOperation",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Item must have valid listId"]
            )
        }
        
        return SyncOperation(
            type: type,
            itemId: item.id,
            listId: listUUID,
            itemSnapshotJSON: itemJSON,
            crdtMetadataJSON: metadataJSON
        )
    }
    
    /// Records a failed attempt and calculates next retry time
    func recordFailure(error: Error, backoff: TimeInterval) {
        retryCount += 1
        lastAttemptAt = Date()
        lastErrorMessage = error.localizedDescription
        
        // Mark as permanently failed if max retries exceeded
        if retryCount >= 20 {
            hasFailed = true
            nextRetryAt = nil
        } else {
            nextRetryAt = Date().addingTimeInterval(backoff)
        }
    }
    
    /// Marks this operation as successfully completed (for removal from queue)
    func markSuccess() {
        lastAttemptAt = Date()
        lastErrorMessage = nil
    }
}

