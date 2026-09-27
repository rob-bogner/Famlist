/*
 WatchListViewModel+Actions.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Aktionen der Uhr – alle über die SyncEngine (sofort lokal sichtbar, danach gesendet; Sofort-Weg zum
   iPhone über den Beobachter der Engine):
   abhaken/wieder öffnen, Menge, hinzufügen (Diktat oder „Oft gekauft“), alle abhaken, zurücksetzen,
   Liste wählen.

 🔰 Notes for Beginners:
 - Hinzufügen wie auf dem iPhone: gleicher Name offen → Menge +1; abgehakt → dieselbe Zeile wieder offen;
   neu → anlegen (aus Liste und Name berechnete ID). Jedes Hinzufügen zählt für „Oft gekauft“.
 - UserLog nur hier (ViewModel), auf Deutsch.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 5).
 ------------------------------------------------------------------------
 */

import Foundation

extension WatchListViewModel {
    // MARK: - Abhaken

    /// Tipp auf den Kreis: abhaken bzw. wieder öffnen.
    func toggle(_ itemId: String) {
        guard var item = items.first(where: { $0.id == itemId }) else { return }
        item.isChecked.toggle()
        write(item)
        if item.isChecked {
            checkFeedback += 1
            UserLog.Data.itemChecked(name: item.name, units: item.units, measure: item.measure)
        } else {
            UserLog.Data.itemUnchecked(name: item.name, units: item.units, measure: item.measure)
        }
    }

    /// „Abhaken“ im Screen „Artikel“.
    func check(_ itemId: String) {
        guard let item = items.first(where: { $0.id == itemId }), !item.isChecked else { return }
        toggle(itemId)
    }

    /// „Alle abhaken“: alle offenen Artikel in EINEM Speicher- und Sende-Durchlauf.
    func checkAll() {
        let open = items.filter { !$0.isChecked }.map { item -> ItemModel in
            var copy = item
            copy.isChecked = true
            return copy
        }
        guard !open.isEmpty else { return }
        checkFeedback += 1
        UserLog.Data.allItemsChecked(count: open.count)
        let engine = sync.engine
        Task { await engine.applyLocalChanges(open) }
    }

    /// „Zurücksetzen“ (Alles erledigt): alle Haken aufheben, gebündelt.
    func resetAll() {
        let checked = items.filter(\.isChecked).map { item -> ItemModel in
            var copy = item
            copy.isChecked = false
            return copy
        }
        guard !checked.isEmpty else { return }
        UserLog.Data.allItemsUnchecked(count: checked.count)
        let engine = sync.engine
        Task { await engine.applyLocalChanges(checked) }
    }

    // MARK: - Menge

    /// Neue Menge (Krone in Ruhe oder ＋/−), 0,01…9999 wie auf dem iPhone (vorher 1…99 – kürzte Grammangaben).
    func setUnits(_ itemId: String, to units: Double) {
        guard var item = items.first(where: { $0.id == itemId }) else { return }
        let clamped = min(max(QuantityFormat.normalized(units), QuantityFormat.range.lowerBound),
                          QuantityFormat.range.upperBound)
        guard clamped != item.units else { return }
        UserLog.Data.itemQuantityChanged(name: item.name, from: item.units, to: clamped, measure: item.measure)
        item.units = clamped
        write(item)
    }

    // MARK: - Hinzufügen

    /// Artikel hinzufügen (Diktat, Tastatur oder „Oft gekauft“).
    func add(name raw: String) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let listId = activeListId else { return }
        let key = ItemIdentity.normalizedKey(name)
        if var open = items.first(where: { ItemIdentity.normalizedKey($0.name) == key && !$0.isChecked }) {
            let old = open.units
            // Eine grobe Stufe mehr (2 → 3 Stück, 1,5 → 2 kg, 500 → 550 g); vorher +1 mit Grenze 99 (500 g wurden 99).
            open.units = QuantityPresets.next(old, up: true, step: QuantityPresets.coarseStep(for: open.measure))
            UserLog.Data.itemCountIncremented(name: open.name, from: old, to: open.units, measure: open.measure)
            write(open)
            noteCatalogUse(open.name, saving: nil)
            return
        }
        // Abgehakt vorhanden → dieselbe Zeile wieder öffnen (Menge 1). Auch Artikel aus der Zeit vor der
        // berechneten ID (Zufalls-ID) bekommen so kein Duplikat.
        if var done = items.first(where: { ItemIdentity.normalizedKey($0.name) == key && $0.isChecked }) {
            done.isChecked = false
            done.units = 1
            UserLog.Data.itemReactivated(name: done.name, units: done.units, measure: done.measure)
            write(done)
            noteCatalogUse(done.name, saving: nil)
            return
        }
        let template = catalogEntry(named: name)
        var item = template?.toItemModel(listId: listId.uuidString, ownerPublicId: nil)
            ?? ItemModel(name: name, units: 1, measure: "", listId: listId.uuidString)
        item.imageData = nil                                     // Fotos nicht von der Uhr aus
        UserLog.Data.itemAdded(name: item.name, units: item.units, measure: item.measure)
        let engine = sync.engine
        Task { await engine.createItem(item) }
        noteCatalogUse(item.name, saving: template == nil ? ItemCatalogEntry.from(item: item, ownerPublicId: "") : nil)
    }

    /// Eintrag im Artikelstamm mit diesem Namen (ohne Groß/klein), für Kategorie und Einheit.
    private func catalogEntry(named name: String) -> ItemCatalogEntry? {
        let key = CatalogOperation.key(name)
        return sync.catalog.store.entries?.first { CatalogOperation.key($0.name) == key }
    }

    /// Artikelstamm: neuen Eintrag speichern (falls nötig), dann zählen – in dieser Reihenfolge.
    private func noteCatalogUse(_ name: String, saving entry: ItemCatalogEntry?) {
        let catalog = sync.catalog
        let usedAt = Date()
        Task {
            if let entry { try? await catalog.save(entry) }
            try? await catalog.noteUse(names: [name], at: usedAt)
            self.rebuild()                                        // „Oft gekauft“ zählt lokal sofort mit
        }
    }

    // MARK: - Listen

    /// Tipp im Screen „Listen“: nur die Liste der Uhr wechselt (Watch-Plan §2).
    func select(_ listId: UUID) {
        defaults.set(listId.uuidString, forKey: Self.activeListKey)
        rebuild()
        UserLog.Data.loadingList(name: title)
    }

    // MARK: - Hilfen

    private func write(_ item: ItemModel) {
        let engine = sync.engine
        Task { await engine.updateItem(item) }
    }
}
