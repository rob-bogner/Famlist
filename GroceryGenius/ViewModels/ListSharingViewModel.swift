// MARK: - ListSharingViewModel
import Foundation

@MainActor
final class ListSharingViewModel: ObservableObject {
    @Published var list: GroceryList
    @Published var partners: [PublicUserId]
    @Published var errorMessage: String?

    private let repo: ListRepository

    init(list: GroceryList, partners: [PublicUserId], repo: ListRepository) {
        self.list = list
        self.partners = partners.sorted { $0.value < $1.value }
        self.repo = repo
    }

    func toggle(_ partner: PublicUserId, isOn: Bool) async {
        if isOn { list.sharedWith.insert(partner) } else { list.sharedWith.remove(partner) }
        do { try await repo.updateList(list) } catch { errorMessage = error.localizedDescription }
    }
}
