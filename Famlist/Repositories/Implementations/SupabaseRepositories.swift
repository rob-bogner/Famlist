/*
 SupabaseRepositories.swift
 GroceryGenius
 Created on: 01.07.2025 (est.)
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Concrete Supabase-backed repositories for profiles, lists, categories, and items.
 🛠 Includes: Protocol conformances, realtime observers, shared data models, and CRUD helpers.
 🔰 Notes for Beginners: These repositories isolate Supabase-specific logic; UI/ViewModels should depend on the protocols instead of concrete types.
 📝 Last Change: Avoid clearing local caches when network fetches fail to support the local-first flow.
 ------------------------------------------------------------------------
*/

import Foundation // Provides UUID, Date, and Codable support used by models.
import Supabase // Brings in Supabase types for queries and builders.

// MARK: - Shared Models
struct Profile: Codable, Identifiable, Hashable {
    let id: UUID
    let publicId: String
    let username: String?
    let fullName: String?
    let avatarUrl: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case publicId = "public_id"
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct List: Codable, Identifiable, Hashable { // Represents a shopping list row from the DB.
    let id: UUID // List id.
    let owner_id: UUID // Owner UUID.
    let title: String // Human-readable list title.
    let is_default: Bool // Whether this is the default list.
    let created_at: Date? // Creation timestamp.
    let updated_at: Date? // Last update timestamp.
}

struct Category: Codable, Identifiable, Hashable { // Category/tag associated with items.
    let id: UUID // Category id.
    let name: String // Category name.
    let emoji: String? // Optional emoji.
    let color_hex: String? // Optional color hex string.
    let profile_id: UUID? // Optional profile owner.
}

/// Authentication-related lightweight error states thrown by repositories when preconditions are not met.
enum AuthError: Error { case unauthenticated } // Thrown when a call requires a logged-in user but none is present.

// MARK: - Protocols
protocol ProfilesRepository { // Profile-related operations.
    func upsertProfile(authUserId: UUID, publicId: String) async throws // Create or update current profile.
    func myProfile() async throws -> Profile // Fetch current profile.
    func profileByPublicId(_ publicId: String) async throws -> Profile? // Look up profile by public id.
}

protocol ListsRepository { // List-related operations for sharing and creation.
    func ensureDefaultListExists(for owner: UUID) async throws -> List // Get or create default list.
    func observeLists(for owner: UUID) -> AsyncStream<[List]> // One-shot stream of lists for owner.
    func createList(for owner: UUID, title: String) async throws -> List // Insert a new list.
    func addMember(listId: UUID, profileId: UUID) async throws // Add a member to list.
    func removeMember(listId: UUID, profileId: UUID) async throws // Remove a member from list.
    // Convenience API returning app-level ListModel for the default list
    func fetchDefaultList(for ownerId: UUID) async throws -> ListModel // Fetch default list or create it if missing.
}

protocol CategoriesRepository { // Category operations.
    func all(for profileId: UUID?) async throws -> [Category] // Fetch all categories for profile or public ones.
    func create(name: String, emoji: String?, colorHex: String?) async throws -> Category // Create a new category.
}

// MARK: - Profiles
final class SupabaseProfilesRepository: ProfilesRepository { // Supabase-backed profiles repo.
    let client: SupabaseClienting // Facade client used for queries.
    init(client: SupabaseClienting) { self.client = client } // Store client.

    func upsertProfile(authUserId: UUID, publicId: String) async throws { // Insert or update the profile row.
        struct Row: Codable { let id: UUID; let public_id: String } // Payload mapping to table columns.
        let row = Row(id: authUserId, public_id: publicId) // Build payload.
        _ = try await client.from("profiles").upsert(row).execute() // Perform upsert; ignore result.
        logVoid(params: (authUserId: authUserId, publicId: publicId)) // Log completion.
    }

    func myProfile() async throws -> Profile { // Fetch current user's profile (server infers user).
        // Resolve authenticated user id from the in-memory user or by awaiting the active session
        if let currentId = client.auth.currentUser?.id { // Prefer currentUser (fast, no await)
            let profile: Profile = try await client
                .from("profiles")
                .select("id, public_id, created_at")
                .eq("id", value: currentId.uuidString)
                .single()
                .execute()
                .value // Decode into Profile
            return logResult(params: ["source": "currentUser"], result: profile)
        }
        // Fallback: try to read/restore session asynchronously and use its user id
        guard let session = try? await client.auth.session else { throw AuthError.unauthenticated } // Session fetch will fail if unauthenticated
        let uid = session.user.id // Extract user id from non-optional Session
        let profile: Profile = try await client
            .from("profiles")
            .select("id, public_id, created_at")
            .eq("id", value: uid.uuidString)
            .single()
            .execute()
            .value // Decode into Profile
        return logResult(params: ["source": "session"], result: profile)
    }

    func profileByPublicId(_ publicId: String) async throws -> Profile? { // Lookup by public id for sharing links.
        let rows: [Profile] = try await client.from("profiles").select().eq("public_id", value: publicId).limit(1).execute().value // Query by public_id.
        let result = rows.first // Return first or nil.
        return logResult(params: ["publicId": publicId], result: result)
    }
}

// MARK: - Lists
final class SupabaseListsRepository: ListsRepository { // Supabase-backed lists repo.
    let client: SupabaseClienting // Facade client.
    init(client: SupabaseClienting) { self.client = client } // Store client.

    func ensureDefaultListExists(for owner: UUID) async throws -> List { // Ensure owner has a default list.
        // fetch
        let fetched: [List] = try await client
            .from("lists")
            .select("id, owner_id, title, is_default, created_at, updated_at")
            .eq("owner_id", value: owner.uuidString)
            .eq("is_default", value: true)
            .limit(1)
            .execute()
            .value
        if let row = fetched.first { return logResult(params: (owner: owner, hit: true), result: row) } // Return existing default when found.
        // insert when none exists - explicitly set owner_id to avoid RLS violations
        struct NewList: Codable { let owner_id: String; let title: String; let is_default: Bool } // Insert payload with explicit owner_id.
        let insert = NewList(owner_id: owner.uuidString, title: "My List", is_default: true) // Default title with explicit owner.
        let inserted: List = try await client
            .from("lists")
            .insert(insert)
            .select("id, owner_id, title, is_default, created_at, updated_at")
            .single()
            .execute()
            .value
        return logResult(params: (owner: owner, created: true), result: inserted) // Return created default list row.
    }

    /// Fetches the default list as an app-level ListModel; creates it if missing. Uses server-side auth for owner_id on insert.
    func fetchDefaultList(for ownerId: UUID) async throws -> ListModel {
        // Row mapping for precise column selection
        struct ListRow: Codable { // Mirrors DB columns.
            let id: UUID // List id.
            let owner_id: UUID // Owner id.
            let title: String // Title.
            let is_default: Bool // Default flag.
            let created_at: Date // Created timestamp (non-null in DB schema).
            let updated_at: Date? // Updated timestamp (nullable for legacy rows).
        }
        // Helper to map DB row -> ListModel with updatedAt fallback
        func map(_ r: ListRow) -> ListModel { // Convert to app model.
            ListModel(
                id: r.id,
                ownerId: r.owner_id,
                title: r.title,
                isDefault: r.is_default,
                createdAt: r.created_at,
                updatedAt: r.updated_at ?? r.created_at
            )
        }
        // 1) Try fetch default for owner
        let fetched: [ListRow] = try await client
            .from("lists")
            .select("id, owner_id, title, is_default, created_at, updated_at")
            .eq("owner_id", value: ownerId.uuidString)
            .eq("is_default", value: true)
            .limit(1)
            .execute()
            .value
        if let row = fetched.first { return logResult(params: (ownerId: ownerId, hit: true), result: map(row)) } // Found existing.
        // 2) Not found -> insert default with explicit owner_id to avoid RLS violations.
        struct NewList: Codable { let owner_id: String; let title: String; let is_default: Bool } // Payload with explicit owner.
        let payload = NewList(owner_id: ownerId.uuidString, title: "My List", is_default: true) // Default attributes with owner.
        let inserted: ListRow = try await client
            .from("lists")
            .insert(payload)
            .select("id, owner_id, title, is_default, created_at, updated_at")
            .single()
            .execute()
            .value
        return logResult(params: (ownerId: ownerId, created: true), result: map(inserted)) // Return new default.
    }

    func observeLists(for owner: UUID) -> AsyncStream<[List]> { // Simple one-shot stream to load lists.
        let stream = AsyncStream { continuation in // Construct a stream.
            Task { // Spawn async work to fetch once then finish.
                let rows: [List] = try await client.from("lists").select().eq("owner_id", value: owner.uuidString).order("created_at").execute().value // Fetch lists for owner.
                continuation.yield(rows) // Send result once.
                continuation.finish() // Close stream.
            }
        }
        return logResult(params: ["owner": owner], result: stream)
    }

    func createList(for owner: UUID, title: String) async throws -> List { // Insert a new list row.
        struct NewList: Codable { let owner_id: UUID; let title: String } // Payload mapping.
        let value: List = try await client.from("lists").insert(NewList(owner_id: owner, title: title)).select().single().execute().value // Insert and return row.
        return logResult(params: (owner: owner, title: title), result: value)
    }

    func addMember(listId: UUID, profileId: UUID) async throws { // Add member to list.
        struct LM: Codable { let list_id: UUID; let profile_id: UUID } // Mapping for list_members table.
        _ = try await client.from("list_members").insert(LM(list_id: listId, profile_id: profileId)).execute() // Execute insert.
        logVoid(params: (listId: listId, profileId: profileId))
    }

    func removeMember(listId: UUID, profileId: UUID) async throws { // Remove member from list.
        _ = try await client.from("list_members").delete().eq("list_id", value: listId.uuidString).eq("profile_id", value: profileId.uuidString).execute() // Delete row by composite PK.
        logVoid(params: (listId: listId, profileId: profileId))
    }
}

// MARK: - Categories
final class SupabaseCategoriesRepository: CategoriesRepository { // Supabase-backed categories repo.
    let client: SupabaseClienting // Facade client.
    init(client: SupabaseClienting) { self.client = client } // Store client.

    func all(for profileId: UUID?) async throws -> [Category] { // Fetch categories visible to profile.
        var query = client.from("categories").select() // Start base select.
        if let profileId { query = query.or("profile_id.eq.\(profileId.uuidString),profile_id.is.null") } // Include global (null) or profile-specific.
        let result: [Category] = try await query.order("name", ascending: true).execute().value // Order by name and return values.
        return logResult(params: ["profileId": profileId as Any], result: result)
    }

    func create(name: String, emoji: String?, colorHex: String?) async throws -> Category { // Insert category.
        struct New: Codable { let name: String; let emoji: String?; let color_hex: String? } // Payload mapping.
        let result: Category = try await client.from("categories").insert(New(name: name, emoji: emoji, color_hex: colorHex)).select().single().execute().value // Insert and return created row.
        return logResult(params: (name: name, emoji: emoji as Any, colorHex: colorHex as Any), result: result)
    }
}

// MARK: - Items (Supabase)
final class SupabaseItemsRepository: ItemsRepository { // Supabase-backed items repo implementing ItemsRepository.
    let client: SupabaseClienting // Facade client used for DB calls.
    init(client: SupabaseClienting) { self.client = client } // Store client.

    // Track continuations with tokens (Continuation is a struct)
    private var continuations: [UUID: [UUID: AsyncStream<[ItemModel]>.Continuation]] = [:] // Observers keyed by list id and token.
    
    // Track Realtime channels for each list to enable cleanup on unsubscribe
    private var channels: [UUID: RealtimeChannelV2] = [:] // Realtime channels keyed by list id.

    func observeItems(listId: UUID) -> AsyncStream<[ItemModel]> { // Start a stream emitting snapshots for a list.
        let stream = AsyncStream { continuation in // Create a stream builder.
            let token = UUID() // Unique token for this subscriber.
            if continuations[listId] == nil { continuations[listId] = [:] } // Ensure bucket for list id exists.
            continuations[listId]?[token] = continuation // Save continuation for later yields.
            
            // Set up Realtime subscription if this is the first observer for this list
            if self.continuations[listId]?.count == 1, self.channels[listId] == nil { // First subscriber for this list.
                Task { await self.setupRealtimeChannel(for: listId) } // Create Realtime channel asynchronously.
            }
            
            continuation.onTermination = { _ in // Cleanup when subscriber cancels.
                self.continuations[listId]?.removeValue(forKey: token) // Remove continuation to avoid leaks.
                // If no more observers for this list, remove the Realtime channel
                if self.continuations[listId]?.isEmpty == true { // Last observer removed.
                    self.teardownRealtimeChannel(for: listId) // Clean up channel.
                    self.continuations.removeValue(forKey: listId) // Remove empty bucket.
                }
            }
            Task { await self.fetchAndYield(listId) } // Send initial snapshot asynchronously.
        }
        return logResult(params: ["listId": listId], result: stream)
    }
    
    /// Sets up a Realtime channel to listen for changes on the items table for a specific list.
    /// Following the pattern from: https://ardyan.medium.com/building-chat-app-with-supabase-swiftui-in-under-100-lines-of-code-d01285f6e87a
    private func setupRealtimeChannel(for listId: UUID) async { // Subscribe to Realtime events using AsyncStream pattern like tutorial.
        let channelId = "public:items:\(listId)" // Unique channel topic - uses "public:" prefix like tutorial.
        logVoid(params: (listId: listId, action: "setupChannel", channelId: channelId)) // Log channel setup.
        
        let channel = client.realtime.channel(channelId) // Create a named channel for this list.
        
        // Create AsyncStreams for each change type using postgresChange with type-safe filter syntax
        // Uses RealtimePostgresFilter enum: .eq("column", value: "value") instead of string-based filters
        let insertions = channel.postgresChange(InsertAction.self, schema: "public", table: "items", filter: .eq("list_id", value: listId.uuidString)) // Stream of INSERT events.
        let updates = channel.postgresChange(UpdateAction.self, schema: "public", table: "items", filter: .eq("list_id", value: listId.uuidString)) // Stream of UPDATE events.
        let deletions = channel.postgresChange(DeleteAction.self, schema: "public", table: "items", filter: .eq("list_id", value: listId.uuidString)) // Stream of DELETE events.
        
        // Subscribe to the channel BEFORE consuming the streams using subscribeWithError for proper error handling
        do {
            try await channel.subscribeWithError() // Start subscription with error reporting.
            logVoid(params: (listId: listId, action: "channelSubscribed", channelId: channelId, status: "success")) // Log successful subscription.
        } catch {
            logVoid(params: (listId: listId, action: "channelSubscribed", channelId: channelId, status: "failed", error: String(describing: error))) // Log subscription error.
            return // Don't start listening tasks if subscription failed.
        }
        
        // Store channel for later cleanup
        channels[listId] = channel // Save channel reference.
        
        // Process insertions in background task (like tutorial: for await insertion in insertions)
        Task {
            for await insertion in insertions { // AsyncStream-based iteration over INSERT events.
                logVoid(params: (listId: listId, action: "realtimeInsert", record: insertion.record)) // Log INSERT.
                await fetchAndYield(listId) // Refresh data.
            }
        }
        
        // Process updates in background task
        Task {
            for await update in updates { // AsyncStream-based iteration over UPDATE events.
                logVoid(params: (listId: listId, action: "realtimeUpdate", record: update.record)) // Log UPDATE.
                await fetchAndYield(listId) // Refresh data.
            }
        }
        
        // Process deletions in background task
        Task {
            for await deletion in deletions { // AsyncStream-based iteration over DELETE events.
                logVoid(params: (listId: listId, action: "realtimeDelete", oldRecord: deletion.oldRecord)) // Log DELETE.
                await fetchAndYield(listId) // Refresh data.
            }
        }
    }
    
    /// Tears down the Realtime channel for a specific list when no more observers exist.
    private func teardownRealtimeChannel(for listId: UUID) { // Unsubscribe and clean up channel.
        guard let channel = channels[listId] else { return } // Nothing to do if no channel exists.
        Task { await channel.unsubscribe() } // Unsubscribe asynchronously.
        channels.removeValue(forKey: listId) // Remove from tracking.
        logVoid(params: (listId: listId, action: "teardownRealtimeChannel")) // Log cleanup.
    }

    @MainActor
    private func yield(_ listId: UUID, _ items: [ItemModel]) { // Yield items to all subscribers for a list.
        continuations[listId]?.values.forEach { $0.yield(items) } // Iterate continuations and push array.
    }

    private func fetchAndYield(_ listId: UUID) async { // Fetch rows for list and emit snapshot.
        struct Row: Codable { // Row mapping from DB columns to Swift.
            let id: UUID // Item id.
            let listId: UUID // List id the item belongs to.
            let ownerPublicId: String? // Optional owner public id.
            let imageData: String? // Base64 image data if any.
            let name: String // Item name.
            let units: Int // Units quantity.
            let measure: String // Measurement unit.
            let price: Double // Price value.
            let isChecked: Bool // Checked flag.
            let category: String? // Category string.
            let productDescription: String? // Description string.
            let brand: String? // Brand string.
            let createdAt: String? // Created timestamp.
            let updatedAt: String? // Updated timestamp.
            enum CodingKeys: String, CodingKey { // Column mapping from snake_case.
                case id
                case listId = "list_id"
                case ownerPublicId = "ownerpublicid"
                case imageData = "imagedata"
                case name, units, measure, price, isChecked, category
                case productDescription = "productdescription"
                case brand
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        do { // Attempt to fetch and map rows.
            let rows: [Row] = try await client.from("items").select().eq("list_id", value: listId.uuidString).execute().value // Fetch list's items in natural database order.
            let mapped = rows.map { r in // Map DB rows to ItemModel values.
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
            await MainActor.run { self.yield(listId, mapped) } // Push snapshot to subscribers on main actor.
            logVoid(params: (listId: listId, itemsCount: mapped.count)) // Log yield summary.
        } catch { // On failure, keep previous snapshot to preserve offline data.
            logVoid(params: (listId: listId, note: "fetchError", error: String(describing: error)))
        }
    }

    func createItem(_ item: ItemModel) async throws -> ItemModel { // Insert a new item then broadcast a refresh.
        // Technical Debt: Still using Base64 imageData instead of Storage URLs
        // See ItemModel.swift for migration plan when DB performance becomes an issue
        let finalImageData: String? = item.imageData // Start with existing base64 if present.
        // Removed redundant check - if imageData is nil, finalImageData is already nil
        struct NewRow: Codable { // Insert payload mapping.
            let id: UUID, listId: UUID, ownerPublicId: String?
            let imageData: String?
            let name: String, units: Int, measure: String, price: Double
            let isChecked: Bool, category: String?, productDescription: String?, brand: String?
            enum CodingKeys: String, CodingKey { case id; case listId = "list_id"; case ownerPublicId = "ownerpublicid"; case imageData = "imagedata"; case name, units, measure, price, isChecked, category; case productDescription = "productdescription"; case brand }
        }
        let listUUID = UUID(uuidString: item.listId ?? "") ?? UUID() // Resolve list UUID from string or fallback.
        let row = NewRow( // Build payload for insert.
            id: UUID(uuidString: item.id) ?? UUID(),
            listId: listUUID,
            ownerPublicId: item.ownerPublicId,
            imageData: finalImageData,
            name: item.name, units: item.units, measure: item.measure, price: item.price,
            isChecked: item.isChecked, category: item.category,
            productDescription: item.productDescription, brand: item.brand
        )
        _ = try await client.from("items").insert(row).execute() // Perform insert.
        await fetchAndYield(listUUID) // Refresh observers.
        let model = ItemModel( // Return the item as stored for local state.
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
        return logResult(params: (itemId: model.id, listId: listUUID), result: model)
    }

    func updateItem(_ item: ItemModel) async throws { // Update an existing item and broadcast.
        let finalImageData: String? = item.imageData // Local immutable copy of image.
        let listId = UUID(uuidString: item.listId ?? "") ?? UUID() // Resolve list id.
        // Removed redundant check - if imageData is nil, finalImageData is already nil
        struct UpdateRow: Encodable { // Update payload mapping.
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
        let payload = UpdateRow( // Build payload with updated fields.
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
        _ = try await client.from("items").update(payload).eq("id", value: item.id).eq("list_id", value: item.listId ?? "").execute() // Update by id & list.
        await fetchAndYield(listId) // Refresh observers.
        logVoid(params: (itemId: item.id, listId: listId))
    }

    func deleteItem(id: String, listId: UUID) async throws { // Delete item row and broadcast.
        _ = try await client.from("items").delete().eq("id", value: id).eq("list_id", value: listId.uuidString).execute() // Perform delete.
        await fetchAndYield(listId) // Refresh observers.
        logVoid(params: (id: id, listId: listId))
    }
}
