// MARK: - ListRepository Protocol (PII-free)
import Foundation

protocol ListRepository: Sendable {
    func observeLists(for owner: PublicUserId) -> AsyncStream<[GroceryList]>
    func createList(_ list: GroceryList) async throws
    func updateList(_ list: GroceryList) async throws
    func deleteList(id: String) async throws
    // Ensure exactly one default list exists for the owner (idempotent)
    func ensureDefaultList(for owner: PublicUserId) async throws
    // NEW
    func getList(for owner: PublicUserId, listId: String) async throws -> GroceryList
    func createSharedList(owners: [PublicUserId]) async throws -> SharedList
    func attachListToShared(owner: PublicUserId, listId: String, sharedId: String) async throws
    func getSharedList(by id: String) async throws -> SharedList?
}
