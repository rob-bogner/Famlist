// MARK: - Supabase Repositories (Profiles, Lists, Items, Categories)

import Foundation
import Supabase

// MARK: - Shared Models
struct Profile: Codable, Identifiable, Hashable { let id: UUID; let public_id: String }

struct List: Codable, Identifiable, Hashable {
    let id: UUID
    let owner_id: UUID
    let title: String
    let is_default: Bool
    let created_at: Date?
}

struct Category: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let emoji: String?
    let color_hex: String?
    let profile_id: UUID?
}

// MARK: - Protocols
protocol ProfilesRepository {
    func upsertProfile(authUserId: UUID, publicId: String) async throws
    func myProfile() async throws -> Profile
    func profileByPublicId(_ publicId: String) async throws -> Profile?
}

protocol ListsRepository {
    func ensureDefaultListExists(for owner: UUID) async throws -> List
    func observeLists(for owner: UUID) -> AsyncStream<[List]>
    func createList(for owner: UUID, title: String) async throws -> List
    func addMember(listId: UUID, profileId: UUID) async throws
    func removeMember(listId: UUID, profileId: UUID) async throws
}

protocol CategoriesRepository {
    func all(for profileId: UUID?) async throws -> [Category]
    func create(name: String, emoji: String?, colorHex: String?) async throws -> Category
}

// MARK: - Profiles
final class SupabaseProfilesRepository: ProfilesRepository {
    let client: SupabaseClienting
    init(client: SupabaseClienting) { self.client = client }

    func upsertProfile(authUserId: UUID, publicId: String) async throws {
        struct Row: Codable { let id: UUID; let public_id: String }
        let row = Row(id: authUserId, public_id: publicId)
        _ = try await client.from("profiles").upsert(row).execute()
    }

    func myProfile() async throws -> Profile {
        return try await client.from("profiles").select().single().execute().value
    }

    func profileByPublicId(_ publicId: String) async throws -> Profile? {
        let rows: [Profile] = try await client.from("profiles").select().eq("public_id", value: publicId).limit(1).execute().value
        return rows.first
    }
}

// MARK: - Lists
final class SupabaseListsRepository: ListsRepository {
    let client: SupabaseClienting
    init(client: SupabaseClienting) { self.client = client }

    func ensureDefaultListExists(for owner: UUID) async throws -> List {
        if let existing: List = try? await client.from("lists").select().eq("owner_id", value: owner.uuidString).eq("is_default", value: true).single().execute().value {
            return existing
        }
        struct NewList: Codable { let owner_id: UUID; let title: String; let is_default: Bool }
        let insert = NewList(owner_id: owner, title: "Einkaufsliste", is_default: true)
        return try await client.from("lists").insert(insert).select().single().execute().value
    }

    func observeLists(for owner: UUID) -> AsyncStream<[List]> {
        AsyncStream { continuation in
            Task {
                let rows: [List] = try await client.from("lists").select().eq("owner_id", value: owner.uuidString).order("created_at").execute().value
                continuation.yield(rows)
                continuation.finish()
            }
        }
    }

    func createList(for owner: UUID, title: String) async throws -> List {
        struct NewList: Codable { let owner_id: UUID; let title: String }
        return try await client.from("lists").insert(NewList(owner_id: owner, title: title)).select().single().execute().value
    }

    func addMember(listId: UUID, profileId: UUID) async throws {
        struct LM: Codable { let list_id: UUID; let profile_id: UUID }
        _ = try await client.from("list_members").insert(LM(list_id: listId, profile_id: profileId)).execute()
    }

    func removeMember(listId: UUID, profileId: UUID) async throws {
        _ = try await client.from("list_members").delete().eq("list_id", value: listId.uuidString).eq("profile_id", value: profileId.uuidString).execute()
    }
}

// MARK: - Categories
final class SupabaseCategoriesRepository: CategoriesRepository {
    let client: SupabaseClienting
    init(client: SupabaseClienting) { self.client = client }

    func all(for profileId: UUID?) async throws -> [Category] {
        var query = client.from("categories").select()
        if let profileId { query = query.or("profile_id.eq.\(profileId.uuidString),profile_id.is.null") }
        return try await query.order("name", ascending: true).execute().value
    }

    func create(name: String, emoji: String?, colorHex: String?) async throws -> Category {
        struct New: Codable { let name: String; let emoji: String?; let color_hex: String? }
        return try await client.from("categories").insert(New(name: name, emoji: emoji, color_hex: colorHex)).select().single().execute().value
    }
}

// MARK: - Items (Supabase)
final class SupabaseItemsRepository: ItemsRepository {
    let client: SupabaseClienting
    init(client: SupabaseClienting) { self.client = client }

    // Track continuations with tokens (Continuation is a struct)
    private var continuations: [UUID: [UUID: AsyncStream<[ItemModel]>.Continuation]] = [:]

    func observeItems(listId: UUID) -> AsyncStream<[ItemModel]> {
        AsyncStream { continuation in
            let token = UUID()
            if continuations[listId] == nil { continuations[listId] = [:] }
            continuations[listId]?[token] = continuation
            continuation.onTermination = { _ in
                self.continuations[listId]?.removeValue(forKey: token)
            }
            Task { await self.fetchAndYield(listId) }
        }
    }

    @MainActor
    private func yield(_ listId: UUID, _ items: [ItemModel]) {
        continuations[listId]?.values.forEach { $0.yield(items) }
    }

    private func fetchAndYield(_ listId: UUID) async {
        struct Row: Codable {
            let id: UUID
            let listId: UUID
            let ownerPublicId: String?
            let imageData: String?
            let name: String
            let units: Int
            let measure: String
            let price: Double
            let isChecked: Bool
            let category: String?
            let productDescription: String?
            let brand: String?
            let position: Int?
            let createdAt: String?
            let updatedAt: String?
            enum CodingKeys: String, CodingKey {
                case id
                case listId = "list_id"
                case ownerPublicId = "ownerpublicid"
                case imageData = "imagedata"
                case name, units, measure, price, isChecked, category
                case productDescription = "productdescription"
                case brand, position
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        do {
            let rows: [Row] = try await client.from("items").select().eq("list_id", value: listId.uuidString).order("position", ascending: true).order("created_at", ascending: true).execute().value
            let mapped = rows.map { r in
                ItemModel(
                    id: r.id.uuidString,
                    imageUrl: nil, // prefer signed URLs only; raw imagedata kept in model for backward compat
                    imageData: r.imageData,
                    name: r.name,
                    units: r.units,
                    measure: r.measure,
                    price: r.price,
                    isChecked: r.isChecked,
                    category: r.category,
                    productDescription: r.productDescription,
                    brand: r.brand,
                    listId: r.listId.uuidString,
                    ownerPublicId: r.ownerPublicId
                )
            }
            await MainActor.run { self.yield(listId, mapped) }
        } catch {
            await MainActor.run { self.yield(listId, []) }
        }
    }

    func createItem(_ item: ItemModel) async throws -> ItemModel {
        var finalImageData: String? = item.imageData
        if finalImageData == nil, let base64 = item.imageData { finalImageData = base64 }
        struct NewRow: Codable {
            let id: UUID, listId: UUID, ownerPublicId: String?
            let imageData: String?
            let name: String, units: Int, measure: String, price: Double
            let isChecked: Bool, category: String?, productDescription: String?, brand: String?
            enum CodingKeys: String, CodingKey { case id; case listId = "list_id"; case ownerPublicId = "ownerpublicid"; case imageData = "imagedata"; case name, units, measure, price, isChecked, category; case productDescription = "productdescription"; case brand }
        }
        let listUUID = UUID(uuidString: item.listId ?? "") ?? UUID()
        let row = NewRow(
            id: UUID(uuidString: item.id) ?? UUID(),
            listId: listUUID,
            ownerPublicId: item.ownerPublicId,
            imageData: finalImageData,
            name: item.name, units: item.units, measure: item.measure, price: item.price,
            isChecked: item.isChecked, category: item.category,
            productDescription: item.productDescription, brand: item.brand
        )
        _ = try await client.from("items").insert(row).execute()
        await fetchAndYield(listUUID)
        return ItemModel(
            id: row.id.uuidString,
            imageUrl: item.imageUrl,
            imageData: finalImageData,
            name: item.name,
            units: item.units,
            measure: item.measure,
            price: item.price,
            isChecked: item.isChecked,
            category: item.category,
            productDescription: item.productDescription,
            brand: item.brand,
            listId: listUUID.uuidString,
            ownerPublicId: item.ownerPublicId
        )
    }

    func updateItem(_ item: ItemModel) async throws {
        var finalImageData: String? = item.imageData
        let listId = UUID(uuidString: item.listId ?? "") ?? UUID()
        if finalImageData == nil, let base64 = item.imageData { finalImageData = base64 }
        struct UpdateRow: Encodable {
            let imageData: String?
            let name: String
            let units: Int
            let measure: String
            let price: Double
            let isChecked: Bool
            let category: String?
            let productDescription: String?
            let brand: String?
            enum CodingKeys: String, CodingKey { case imageData = "imagedata"; case name, units, measure, price, isChecked, category; case productDescription = "productdescription"; case brand }
        }
        let payload = UpdateRow(
            imageData: finalImageData,
            name: item.name,
            units: item.units,
            measure: item.measure,
            price: item.price,
            isChecked: item.isChecked,
            category: item.category,
            productDescription: item.productDescription,
            brand: item.brand
        )
        _ = try await client.from("items").update(payload).eq("id", value: item.id).eq("list_id", value: item.listId ?? "").execute()
        await fetchAndYield(listId)
    }

    func deleteItem(id: String, listId: UUID) async throws {
        _ = try await client.from("items").delete().eq("id", value: id).eq("list_id", value: listId.uuidString).execute()
        await fetchAndYield(listId)
    }
}
