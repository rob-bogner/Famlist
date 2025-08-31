// MARK: - ListSharing Views
import SwiftUI

struct ListSharingView: View {
    let publicId: PublicUserId
    @State private var lists: [GroceryList] = []
    @State private var errorMessage: String?

    private let listRepo: ListRepository

    init(publicId: PublicUserId, listRepo: ListRepository = FirestoreListRepository()) {
        self.publicId = publicId
        self.listRepo = listRepo
    }

    var body: some View {
        List {
            let ownedLists = lists.filter { $0.owner == publicId }
            if ownedLists.isEmpty {
                Text("No lists yet").foregroundStyle(.secondary)
            }
            ForEach(ownedLists, id: \.id) { list in
                NavigationLink(destination: ListSharingDetailView(list: list, partners: [], repo: listRepo)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(list.name).font(.headline)
                        let shared = list.sharedWith.map { $0.value }.sorted()
                        if !shared.isEmpty {
                            Text("Shared with: \(shared.joined(separator: ", "))")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        } else {
                            Text("Private").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("List Sharing")
        .onAppear { observeLists() }
        .alert(item: Binding(get: { errorMessage.map { IdentifiedAlert(message: $0) } }, set: { _ in errorMessage = nil })) { ia in
            Alert(title: Text("Error"), message: Text(ia.message), dismissButton: .default(Text("OK")))
        }
    }

    private func observeLists() {
        Task { @MainActor in
            for await snapshot in listRepo.observeLists(for: publicId) {
                self.lists = snapshot
            }
        }
    }
}

private struct ListSharingDetailView: View {
    @StateObject private var vm: ListSharingViewModel
    @State private var localError: String?

    init(list: GroceryList, partners: [PublicUserId], repo: ListRepository) {
        _vm = StateObject(wrappedValue: ListSharingViewModel(list: list, partners: partners, repo: repo))
    }
    var body: some View {
        Form {
            Section("Partners") {
                ForEach(vm.partners, id: \.self) { p in
                    Toggle(isOn: Binding(
                        get: { vm.list.sharedWith.contains(p) },
                        set: { newVal in Task { await vm.toggle(p, isOn: newVal); if let e = vm.errorMessage { localError = e } } }
                    )) {
                        Text(p.value).font(.body.monospaced())
                    }
                }
            }
        }
        .navigationTitle(vm.list.name)
        .alert(item: Binding(get: { (localError ?? vm.errorMessage).map { IdentifiedAlert(message: $0) } }, set: { _ in localError = nil; vm.errorMessage = nil })) { ia in
            Alert(title: Text("Error"), message: Text(ia.message), dismissButton: .default(Text("OK")))
        }
    }
}

#Preview {
    NavigationStack {
        ListSharingView(publicId: PreviewData.publicId, listRepo: PreviewListRepository())
    }
}
