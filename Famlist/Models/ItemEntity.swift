/*
 ItemEntity.swift
 GroceryGenius
 Created on: 12.10.2025
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: SwiftData item model shared with Supabase JSON payloads.
 🛠 Includes: @Model declaration, Codable bridge, sync-state helpers, relationship to parent list.
 🔰 Notes for Beginners: Represents a product entry; syncStatus steuert, ob Datensätze zur Cloud synchronisiert werden müssen.
 📝 Last Change: Removed explicit SwiftData relationship macro to fix circular reference build errors.
 ------------------------------------------------------------------------
*/

import Foundation
import SwiftData

/// Represents a shopping list item that persists locally via SwiftData and syncs with Supabase.
@Model
final class ItemEntity: Identifiable, Codable {
    /// Synchronisation states for the item lifecycle.
    enum SyncStatus: Int, Codable {
        case pendingCreate
        case pendingUpdate
        case pendingDelete
        case pendingRecovery
        case failed
        case synced
    }

    @Attribute(.unique) var id: UUID
    var listId: UUID
    var ownerPublicId: String?
    var imageData: String?
    var name: String
    var units: Int
    var measure: String
    var price: Double
    var isChecked: Bool
    var category: String?
    var productDescription: String?
    var brand: String?
    var position: Int?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var list: ListEntity? // Optional reference to parent list without explicit relationship macro to avoid circular issue.

    private var syncStatusRawValue: Int

    /// Computed accessor for the item synchronisation state.
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRawValue) ?? .synced }
        set { syncStatusRawValue = newValue.rawValue }
    }

    /// Convenience helper indicating soft deletion state.
    var isSoftDeleted: Bool { deletedAt != nil }

    /// Designated initialiser for SwiftData and manual creation.
    init(
        id: UUID = UUID(),
        listId: UUID,
        ownerPublicId: String?,
        imageData: String?,
        name: String,
        units: Int,
        measure: String,
        price: Double,
        isChecked: Bool,
        category: String?,
        productDescription: String?,
        brand: String?,
        position: Int?,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
    deletedAt: Date? = nil,
    list: ListEntity? = nil,
        syncStatus: SyncStatus = .synced
    ) {
        self.id = id
        self.listId = listId
        self.ownerPublicId = ownerPublicId
        self.imageData = imageData
        self.name = name
        self.units = units
        self.measure = measure
        self.price = price
        self.isChecked = isChecked
        self.category = category
        self.productDescription = productDescription
        self.brand = brand
        self.position = position
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.list = list
        self.syncStatusRawValue = syncStatus.rawValue
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id
        case listId = "list_id"
        case ownerPublicId = "ownerpublicid"
        case imageData = "imagedata"
        case name
        case units
        case measure
        case price
        case isChecked
        case category
        case productDescription = "productdescription"
        case brand
        case position
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    /// Decodes the entity from Supabase JSON payloads.
    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let listId = try container.decode(UUID.self, forKey: .listId)
        let ownerPublicId = try container.decodeIfPresent(String.self, forKey: .ownerPublicId)
        let imageData = try container.decodeIfPresent(String.self, forKey: .imageData)
        let name = try container.decode(String.self, forKey: .name)
        let units = try container.decode(Int.self, forKey: .units)
        let measure = try container.decode(String.self, forKey: .measure)
        let price = try container.decode(Double.self, forKey: .price)
        let isChecked = try container.decode(Bool.self, forKey: .isChecked)
        let category = try container.decodeIfPresent(String.self, forKey: .category)
        let productDescription = try container.decodeIfPresent(String.self, forKey: .productDescription)
        let brand = try container.decodeIfPresent(String.self, forKey: .brand)
        let position = try container.decodeIfPresent(Int.self, forKey: .position)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)
        let updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        let deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        self.init(
            id: id,
            listId: listId,
            ownerPublicId: ownerPublicId,
            imageData: imageData,
            name: name,
            units: units,
            measure: measure,
            price: price,
            isChecked: isChecked,
            category: category,
            productDescription: productDescription,
            brand: brand,
            position: position,
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
        try container.encode(listId, forKey: .listId)
        try container.encodeIfPresent(ownerPublicId, forKey: .ownerPublicId)
        try container.encodeIfPresent(imageData, forKey: .imageData)
        try container.encode(name, forKey: .name)
        try container.encode(units, forKey: .units)
        try container.encode(measure, forKey: .measure)
        try container.encode(price, forKey: .price)
        try container.encode(isChecked, forKey: .isChecked)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(productDescription, forKey: .productDescription)
        try container.encodeIfPresent(brand, forKey: .brand)
        try container.encodeIfPresent(position, forKey: .position)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
    }

    // MARK: - Sync Helpers

    /// Adjusts timestamps and the soft-delete flag when changing the sync status.
    func setSyncStatus(_ status: SyncStatus) {
        switch status {
        case .pendingCreate:
            createdAt = Date()
            updatedAt = Date()
            if deletedAt != nil { deletedAt = nil }
        case .pendingUpdate:
            updatedAt = Date()
        case .pendingDelete:
            deletedAt = deletedAt ?? Date()
        case .pendingRecovery:
            deletedAt = nil
            updatedAt = Date()
        case .failed, .synced:
            break
        }
        syncStatus = status
    }
}
