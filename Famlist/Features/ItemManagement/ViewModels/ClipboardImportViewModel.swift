/*
 ClipboardImportViewModel.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zustand von „Import aus Zwischenablage“: Text lesen, erkannte Artikel, Auswahl, Übernahme in die Liste.

 🔰 Notes for Beginners:
 - Die Übernahme läuft über ImportMergeService: Gleichnamige Artikel werden erhöht oder wieder geöffnet,
   neue Artikel angelegt. Geschrieben wird lokal; die SyncEngine sendet im Hintergrund.
 - `readClipboard` ist austauschbar, damit Tests und Vorschauen keinen echten Zwischenspeicher brauchen.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026, Import als Hybrid-Sheet).
 ------------------------------------------------------------------------
 */

import SwiftUI

@MainActor
final class ClipboardImportViewModel: ObservableObject {
    @Published private(set) var result: ClipboardImportParser.ParseResult?
    @Published private(set) var errorMessage: String?
    @Published private(set) var selected: Set<Int> = []

    private let readClipboard: () -> String?

    init(readClipboard: @escaping () -> String? = { UIPasteboard.general.string }) {
        self.readClipboard = readClipboard
    }

    var items: [ClipboardImportParser.ParsedItem] { result?.items ?? [] }
    var allSelected: Bool { !items.isEmpty && selected.count == items.count }

    /// Liest die Zwischenablage und wählt alle erkannten Artikel aus.
    func load() {
        logVoid()
        guard let text = readClipboard(), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            show(error: String(localized: "import.error.emptyClipboard"))
            return
        }
        let parsed = ClipboardImportParser.parse(text)
        guard !parsed.items.isEmpty else {
            show(error: String(localized: "import.error.noItemsFound"))
            return
        }
        result = parsed
        selected = Set(parsed.items.indices)
        errorMessage = nil
    }

    func toggle(_ index: Int) {
        if selected.contains(index) { selected.remove(index) } else { selected.insert(index) }
    }

    func toggleAll() {
        selected = allSelected ? [] : Set(items.indices)
    }

    /// Übernimmt die ausgewählten Artikel in die geöffnete Liste. Gibt die Anzahl zurück.
    @discardableResult
    func importSelected(into listViewModel: ListViewModel) -> Int {
        let chosen = selected.sorted().compactMap { items.indices.contains($0) ? items[$0] : nil }
        guard !chosen.isEmpty else { return 0 }
        let merge = ImportMergeService.merge(selected: chosen,
                                             allLocalItems: listViewModel.fetchAllLocalItems(),
                                             listId: listViewModel.listId)
        guard !merge.targets.isEmpty else { return 0 }
        listViewModel.applyBulkImport(merge)
        return chosen.count
    }

    private func show(error: String) {
        result = nil
        selected = []
        errorMessage = error
    }
}
