// MARK: - ItemsRepository.swift

/*
 File: ItemsRepository.swift
 Project: GroceryGenius
 Created: 27.11.2023
 Last Updated: 17.08.2025

 Overview:
 Abstraction boundary for data access to shopping list items. Enables swapping Firestore implementation with mocks or future local persistence without touching higher layers (ViewModels / Views).

 Responsibilities / Includes:
 - CRUD contracts (add / update / delete)
 - Real-time subscription contract (addListener)
 - Error type enumerating common repository-level failures

 Design Notes:
 - ListenerToken kept as AnyObject to avoid leaking Firestore dependency (ListenerRegistration) into callers
 - Errors intentionally minimal; UI maps to localized strings via LocalizedError
 - All mutation methods are asynchronous via completion to support both network & local backends uniformly

 Possible Enhancements:
 - Add async/await overloads for modern concurrency
 - Extend error cases (permissionDenied, rateLimited, offline)
 - Provide pagination / query filters
*/

import Foundation

// MARK: - Repository Errors

enum ItemsRepositoryError: Error, LocalizedError {
    case notFound
    case decodingFailed
    case encodingFailed
    case network(String)
    case unknown
    var errorDescription: String? {
        switch self {
        case .notFound: return String(localized: "error.repository.not_found")
        case .decodingFailed: return String(localized: "error.repository.decode")
        case .encodingFailed: return String(localized: "error.repository.encode")
        case .network(let msg): return String(format: String(localized: "error.repository.network"), msg)
        case .unknown: return String(localized: "error.repository.unknown")
        }
    }
}

// MARK: - Creation Payload

struct NewItemPayload: Sendable, Codable, Hashable {
    var id: String?
    var imageData: String?
    var name: String
    var units: Int
    var measure: String
    var price: Double
    var isChecked: Bool
    var category: String?
    var productDescription: String?
    var brand: String?
}

// MARK: - Protocol

protocol ItemsRepository: Sendable {
    func observeItems(for owner: PublicUserId, listId: String) -> AsyncStream<[ItemModel]>
    func createItem(for owner: PublicUserId, listId: String, payload: NewItemPayload) async throws -> ItemModel
    func updateItem(for owner: PublicUserId, listId: String, item: ItemModel) async throws
    func deleteItem(for owner: PublicUserId, listId: String, itemId: String) async throws
}

// MARK: - List Context (for shared vs user-scoped items)
struct ListContext: Sendable, Hashable {
    let owner: PublicUserId
    let listId: String
    let sharedListId: String? // nil → user scope; otherwise shared scope
}

// MARK: - Context-first convenience APIs (defaulted to existing methods)
extension ItemsRepository {
    func observeItems(in ctx: ListContext) -> AsyncStream<[ItemModel]> {
        observeItems(for: ctx.owner, listId: ctx.listId)
    }
    func createItem(in ctx: ListContext, payload: NewItemPayload) async throws -> ItemModel {
        try await createItem(for: ctx.owner, listId: ctx.listId, payload: payload)
    }
    func updateItem(in ctx: ListContext, item: ItemModel) async throws {
        try await updateItem(for: ctx.owner, listId: ctx.listId, item: item)
    }
    func deleteItem(in ctx: ListContext, itemId: String) async throws {
        try await deleteItem(for: ctx.owner, listId: ctx.listId, itemId: itemId)
    }
}
