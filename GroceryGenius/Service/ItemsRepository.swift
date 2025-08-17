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

// MARK: - Protocol

protocol ItemsRepository {
    typealias ListenerToken = AnyObject
    @discardableResult
    func addListener(onUpdate: @escaping ([ItemModel]) -> Void) -> ListenerToken
    func addItem(_ item: ItemModel, completion: ((Error?) -> Void)?)
    func updateItem(_ item: ItemModel, completion: ((Error?) -> Void)?)
    func deleteItem(_ item: ItemModel, completion: ((Error?) -> Void)?)
}
