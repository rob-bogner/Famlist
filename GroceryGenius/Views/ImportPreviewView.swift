// filepath: GroceryGenius/Views/ImportPreviewView.swift
// MARK: - ImportPreviewView.swift

import SwiftUI

struct ImportPreviewView: View {
    // Input: parsed items from clipboard
    let items: [ImportedItem]
    let onCancel: () -> Void
    // New: return only selected items
    let onImport: ([ImportedItem]) -> Void

    // Selection model
    struct ImportCandidate: Identifiable, Hashable {
        let id: UUID = .init()
        let title: String
        let note: String?
        let qty: Double?
        let unit: String?
        let category: String?
        var isSelected: Bool = true
    }
    struct ImportSection: Identifiable, Hashable {
        let id: String
        let category: String
        var items: [ImportCandidate]
    }

    @State private var candidates: [ImportCandidate] = []

    private var selectedCount: Int { candidates.filter { $0.isSelected }.count }

    private var sections: [ImportSection] {
        // Build sections grouped by category, preserving item order
        let other = String(localized: "category.other", table: "Localizable")
        var grouped: [String: [ImportCandidate]] = [:]
        for c in candidates {
            let key = (c.category?.isEmpty == false ? c.category! : other)
            grouped[key, default: []].append(c)
        }
        let sortedKeys = grouped.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return sortedKeys.map { k in ImportSection(id: k, category: k, items: grouped[k] ?? []) }
    }

    init(items: [ImportedItem], onCancel: @escaping () -> Void, onImport: @escaping ([ImportedItem]) -> Void) {
        self.items = items
        self.onCancel = onCancel
        self.onImport = onImport
        // _candidates will be initialized in onAppear to avoid SwiftUI init/state pitfalls
    }

    var body: some View {
        CustomModalView(title: String(localized: "import.title"), onClose: onCancel) {
            VStack(spacing: 0) {
                // Removed separate accent header; CustomModalView provides the header.

                // Action row
                HStack {
                    Button(action: { selectAll(true) }) {
                        Text("import.selectAll", tableName: "Localizable")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("selectAllButton")
                    .overlay(EmptyView())
                    .padding(.leading, 16)

                    Button(action: { selectAll(false) }) {
                        Text("import.deselectAll", tableName: "Localizable")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("deselectAllButton")

                    Spacer()

                    Text(String(format: String(localized: "import.selected.count", table: "Localizable"), selectedCount))
                        .font(.callout)
                        .padding(.trailing, 16)
                }
                .padding(.vertical, 8)

                // Scrollable, grouped list
                List {
                    ForEach(sections) { section in
                        Section(section.category) {
                            ForEach(section.items) { item in
                                ImportPreviewRow(item: item) { toggle(item) }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .environment(\.defaultMinListRowHeight, 44)

                // Footer actions
                HStack {
                    Button(action: onCancel) { Text("import.button.cancel", tableName: "Localizable") }
                        .buttonStyle(.bordered)

                    Spacer()

                    Button(String(format: String(localized: "import.button.import.n", table: "Localizable"), selectedCount)) {
                        importSelected()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedCount == 0)
                }
                .padding(16)
            }
            .background(Color.theme.background)
            .onAppear(perform: buildCandidates)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .background(Color.clear)
    }

    // MARK: - Build candidates
    private func buildCandidates() {
        if !candidates.isEmpty { return }
        candidates = items.map { itm in
            ImportCandidate(title: itm.title, note: itm.note, qty: itm.qty, unit: itm.unit, category: itm.category ?? nil, isSelected: true)
        }
    }

    // MARK: - Selection helpers
    private func selectAll(_ flag: Bool) {
        candidates = candidates.map { c in var m = c; m.isSelected = flag; return m }
    }

    private func toggle(_ item: ImportCandidate) {
        if let idx = candidates.firstIndex(where: { $0.id == item.id }) {
            candidates[idx].isSelected.toggle()
        }
    }

    private func importSelected() {
        let selected = candidates.filter { $0.isSelected }
        let mapped: [ImportedItem] = selected.map { c in ImportedItem(title: c.title, note: c.note, qty: c.qty, unit: c.unit, category: c.category) }
        onImport(mapped)
    }
}

#Preview {
    ImportPreviewView(items: [
        ImportedItem(title: "Champignons", note: "in Scheiben", qty: 200, unit: "g", category: "Obst & Gemüse"),
        ImportedItem(title: "Frühlingszwiebel(n)", note: nil, qty: 0.5, unit: "Bund", category: "Obst & Gemüse"),
        ImportedItem(title: "Wurst", note: nil, qty: nil, unit: nil, category: "Fleisch & Wurst")
    ], onCancel: {}, onImport: { _ in })
}
