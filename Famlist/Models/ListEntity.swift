/*
 ListEntity.swift
 Famlist
 Created on: 12.10.2025
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: SwiftData-backed list model shared between local store and Supabase payloads.
 🛠 Includes: @Model declaration, Codable bridge, sync-state helpers, relationship to items.
 🔰 Notes for Beginners: Represents a shopping list row; syncStatus tracks pending operations for background sync.
 📝 Last Change: Reverted to plain array relationship to avoid SwiftData macro circular reference build errors.
 ------------------------------------------------------------------------
*/

import Foundation
import SwiftData

/// Represents a shopping list entry that can be stored locally via SwiftData and encoded/decoded for Supabase interactions.
@Model
final class ListEntity: Identifiable, Codable {
    /// Synchronisation states for local-first workflows.
    enum SyncStatus: Int, Codable {
        case pendingCreate
        case pendingUpdate
        case pendingDelete
        case failed
        case synced
    }

    @Attribute(.unique) var id: UUID
    var ownerId: UUID?
    var title: String
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var items: [ItemEntity] = [] // Plain array to represent relationship; avoids macro circular reference.

    private var syncStatusRawValue: Int

    /// Computed accessor for the synchronisation status backed by `syncStatusRawValue`.
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRawValue) ?? .synced }
        set { syncStatusRawValue = newValue.rawValue }
    }

    /// Convenience flag signalling soft deletion state.
    var isSoftDeleted: Bool { deletedAt != nil }

    /// Designated initialiser used by SwiftData and manual construction.
    init(
        id: UUID = UUID(),
        ownerId: UUID?,
        title: String,
        isDefault: Bool,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
    deletedAt: Date? = nil,
    items: [ItemEntity] = [],
        syncStatus: SyncStatus = .synced
    ) {
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.items = items
        self.syncStatusRawValue = syncStatus.rawValue
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case title
        case isDefault = "is_default"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    /// Decodes the entity from Supabase JSON payloads.
    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let ownerId = try container.decodeIfPresent(UUID.self, forKey: .ownerId)
        let title = try container.decode(String.self, forKey: .title)
        let isDefault = try container.decode(Bool.self, forKey: .isDefault)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)
        let updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        let deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        self.init(
            id: id,
            ownerId: ownerId,
            title: title,
            isDefault: isDefault,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            syncStatus: .synced
        )
    }

    /// Encodes the entity for Supabase mutations.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(ownerId, forKey: .ownerId)
        try container.encode(title, forKey: .title)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
    }

    // MARK: - Sync Helpers

    /// Helper to adjust timestamps and soft-delete flags when the sync status changes.
    func setSyncStatus(_ status: SyncStatus) {
        switch status {
        case .pendingCreate:
            createdAt = Date()
            updatedAt = Date()
        case .pendingUpdate:
            updatedAt = Date()
        case .pendingDelete:
            deletedAt = deletedAt ?? Date()
        case .failed, .synced:
            break
        }
        syncStatus = status
    }
}
