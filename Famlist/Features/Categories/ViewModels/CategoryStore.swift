/*
 CategoryStore.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hält die Kategorien des Nutzers in Ladenweg-Reihenfolge: laden, anlegen, bearbeiten, löschen, umsortieren.

 🔰 Notes for Beginners:
 - Offline-first light: Die Liste liegt als Cache in UserDefaults (pro Profil) und ist sofort da.
   Änderungen gelten sofort lokal; das Speichern in Supabase läuft im Hintergrund.
 - Beim ersten Start eines Kontos (keine Kategorien in Supabase) werden die 8 Standard-Kategorien angelegt.
 - „Sonstiges“ ist immer vorhanden und kann nicht gelöscht werden.
 - Umbenennen/Löschen liefert den alten Namen zurück; die Liste ordnet dann die Artikel neu zu.
 - Schreibaufträge an Supabase laufen strikt nacheinander (sonst könnten schnelle Änderungen vertauscht ankommen).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 6).
 ------------------------------------------------------------------------
 */

import Foundation

@MainActor
final class CategoryStore: ObservableObject {
    @Published private(set) var categories: [CategoryDefinition] = CategoryDefinition.defaults
    @Published var errorMessage: String?

    private let repository: CategoryDefinitionsRepository?
    private let defaults: UserDefaults
    private var profileId: UUID?
    /// Letzter Schreibauftrag; neue warten darauf, damit Supabase die Änderungen in Tipp-Reihenfolge erhält.
    private var writeTask: Task<Void, Never>?

    init(repository: CategoryDefinitionsRepository?, defaults: UserDefaults = .standard) {
        self.repository = repository
        self.defaults = defaults
    }

    private func cacheKey(_ id: UUID) -> String { "categoryDefinitions.\(id.uuidString)" }

    /// Nach der Anmeldung: Cache sofort, dann Supabase; leeres Konto → Standard-Kategorien anlegen.
    func load(profileId: UUID) async {
        self.profileId = profileId
        if let data = defaults.data(forKey: cacheKey(profileId)),
           let cached = try? JSONDecoder().decode([CategoryDefinition].self, from: data), !cached.isEmpty {
            categories = normalized(cached)
        }
        guard let repository else { return }
        do {
            let remote = try await repository.fetch(profileId: profileId)
            if remote.isEmpty {
                let seed = categories.isEmpty ? CategoryDefinition.defaults : categories
                categories = normalized(seed)
                let seeded = categories
                enqueue { try await repository.upsert(seeded, profileId: profileId) }
            } else {
                categories = normalized(remote)
            }
            saveCache()
        } catch {
            logVoid(params: (action: "categories.load.error", error: (error as NSError).localizedDescription))
        }
    }

    // MARK: - Ändern

    /// Neue Kategorie ans Ende vor „Sonstiges“. Liefert false bei leerem oder doppeltem Namen.
    @discardableResult
    func add(name raw: String, icon: String) -> Bool {
        let name = raw.trimmingCharacters(in: .whitespaces)
        guard isAvailable(name) else { return false }
        var list = categories
        let insertAt = list.firstIndex(where: \.isFallback) ?? list.count
        list.insert(CategoryDefinition(id: UUID(), name: name, icon: icon, position: 0), at: insertAt)
        apply(list, changed: nil)
        UserLog.Data.categoryCreated(name: name)
        return true
    }

    /// Name/Icon ändern. Liefert den alten Namen, wenn er sich geändert hat (Artikel neu zuordnen).
    func update(_ id: UUID, name raw: String, icon: String) -> String? {
        guard let index = categories.firstIndex(where: { $0.id == id }) else { return nil }
        var list = categories
        let old = list[index]
        let name = old.isFallback ? old.name : raw.trimmingCharacters(in: .whitespaces)   // „Sonstiges“ bleibt
        guard name == old.name || isAvailable(name, except: id) else { return nil }
        list[index].name = name
        list[index].icon = icon
        apply(list, changed: [list[index]])
        UserLog.Data.categoryUpdated(name: name)
        return name == old.name ? nil : old.name
    }

    /// Löschen (nicht „Sonstiges“). Liefert den gelöschten Namen (Artikel → „Sonstiges“).
    func delete(_ id: UUID) -> String? {
        guard let target = categories.first(where: { $0.id == id }), !target.isFallback else { return nil }
        apply(categories.filter { $0.id != id }, changed: nil)
        UserLog.Data.categoryDeleted(name: target.name)
        if let repository {
            enqueue { try await repository.delete(id: id) }
        }
        return target.name
    }

    /// Ziehen: Kategorie `id` an die Stelle von `targetId`.
    func move(_ id: UUID, to targetId: UUID) {
        guard id != targetId, let from = categories.firstIndex(where: { $0.id == id }),
              let to = categories.firstIndex(where: { $0.id == targetId }) else { return }
        var list = categories
        let moved = list.remove(at: from)
        list.insert(moved, at: to)
        apply(list, changed: nil)
    }

    /// VoiceOver / Knöpfe: eine Position nach oben (−1) oder unten (+1).
    func move(_ id: UUID, by delta: Int) {
        guard let from = categories.firstIndex(where: { $0.id == id }) else { return }
        let to = from + delta
        guard categories.indices.contains(to) else { return }
        move(id, to: categories[to].id)
    }

    func isAvailable(_ name: String, except id: UUID? = nil) -> Bool {
        !name.isEmpty && !categories.contains {
            $0.id != id && $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    // MARK: - Intern

    /// Positionen neu durchzählen, „Sonstiges“ sicherstellen, Cache + Supabase schreiben.
    private func apply(_ list: [CategoryDefinition], changed: [CategoryDefinition]?) {
        let before = categories
        categories = normalized(list, renumber: true)
        saveCache()
        guard let repository, let profileId else { return }
        let dirty = categories.filter { c in before.first(where: { $0.id == c.id }) != c }
        enqueue { try await repository.upsert(dirty, profileId: profileId) }
    }

    /// Hängt einen Schreibauftrag hinten an; Fehler landen in `errorMessage` (lokal bleibt die Änderung).
    private func enqueue(_ work: @escaping () async throws -> Void) {
        let previous = writeTask
        writeTask = Task {
            await previous?.value
            do {
                try await work()
            } catch {
                errorMessage = "Kategorien konnten nicht gespeichert werden."
                logVoid(params: (action: "categories.save.error", error: (error as NSError).localizedDescription))
            }
        }
    }

    /// Nur für Tests: wartet, bis alle Schreibaufträge erledigt sind.
    func waitForWrites() async { await writeTask?.value }

    private func normalized(_ list: [CategoryDefinition], renumber: Bool = false) -> [CategoryDefinition] {
        var sorted = renumber ? list : list.sorted { $0.position < $1.position }
        if !sorted.contains(where: \.isFallback) {
            sorted.append(CategoryDefinition(id: UUID(), name: CategoryDefinition.fallbackName, icon: "tag",
                                             position: sorted.count))
        }
        return sorted.enumerated().map { index, c in
            var copy = c
            copy.position = index
            return copy
        }
    }

    private func saveCache() {
        guard let profileId, let data = try? JSONEncoder().encode(categories) else { return }
        defaults.set(data, forKey: cacheKey(profileId))
    }
}
