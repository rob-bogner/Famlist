// MARK: - ListRepository Protocol (PII-free)
import Foundation

protocol ListRepository: Sendable {
    func observeLists(for owner: PublicUserId) -> AsyncStream<[GroceryList]>
    func createList(_ list: GroceryList) async throws
    func updateList(_ list: GroceryList) async throws
    func deleteList(id: String) async throws
}
