/*
 ListViewModel+Sections.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sichtbare Abschnitte der Liste (Sortierung + Tab) und manuelles Umsortieren per Ziehen.

 🔰 Notes for Beginners:
 - Die Abschnitte berechnet ListSectionBuilder (reine Funktion). Diese Extension liefert nur
   die aktuellen Eingaben aus dem ViewModel.
 - Sortier-Einstellung und manuelle Reihenfolge werden beim Listenwechsel neu geladen
   (`loadListPreferences`, aufgerufen aus `listId.didSet`).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Dock „Sortieren“).
 ------------------------------------------------------------------------
 */

import SwiftUI

extension ListViewModel {
    /// Abschnitte, die ShoppingListContent zeichnet.
    var visibleSections: [ListSection] {
        ListSectionBuilder.sections(items: items, settings: sortSettings, filter: itemFilter,
                                    manualOrder: manualOrder)
    }

    /// Abschnitte ohne Tab-Filter – Reihenfolge für „In Zwischenablage kopieren“.
    var visibleSectionsIgnoringFilter: [ListSection] {
        ListSectionBuilder.sections(items: items, settings: sortSettings, filter: .all, manualOrder: manualOrder)
    }

    /// Lädt die Mitglieder der aktiven Liste (ohne Eigentümer). Fehler lassen die alte Liste stehen.
    func loadActiveListMembers() {
        guard let repo = listsRepository else { return }
        let id = listId
        Task { [weak self] in
            guard let members = try? await repo.fetchMembers(listId: id) else { return }
            await MainActor.run {
                guard let self, self.listId == id else { return }
                self.activeListMembers = members
            }
        }
    }

    /// Lädt Sortier-Einstellung und manuelle Reihenfolge der aktiven Liste.
    func loadListPreferences() {
        sortSettings = ListSortSettings.load(listId: listId)
        manualOrder = ManualOrderStore.load(listId: listId)
        activeListMembers = []
    }

    /// Manuell: verschiebt `itemId` an die Stelle von `targetId` (Ziehen & Ablegen).
    /// Schaltet die Sortierung dabei auf „Manuell“, damit die neue Reihenfolge sichtbar bleibt.
    func moveItem(_ itemId: String, to targetId: String) {
        guard itemId != targetId else { return }
        var order = visibleSections.flatMap { $0.items.map(\.id) }
        for id in items.map(\.id) where !order.contains(id) { order.append(id) }
        guard let from = order.firstIndex(of: itemId), let to = order.firstIndex(of: targetId) else { return }
        order.remove(at: from)
        order.insert(itemId, at: to)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            manualOrder = order
            if sortSettings.order != .manual { sortSettings.order = .manual }
        }
        ManualOrderStore.save(order, listId: listId)
        sortSettings.save(listId: listId)
    }
}
