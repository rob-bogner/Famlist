/*
 CategoryStore.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hält die Kategorien des Nutzers in Ladenweg-Reihenfolge: laden, anlegen, bearbeiten, löschen, umsortieren.

 🔰 Notes for Beginners:
 - Offline zuerst: Die Liste liegt in UserDefaults (pro Profil) und ist sofort da. Änderungen werden
   als „offen“ gemerkt (übersteht Neustarts) und gesendet, sobald Netz da ist.
   Änderungen gelten sofort lokal; das Speichern in Supabase läuft im Hintergrund.
 - Beim ersten Start eines Kontos (keine Kategorien in Supabase) werden die 8 Standard-Kategorien angelegt.
 - „Sonstiges“ ist immer vorhanden und kann nicht gelöscht werden.
 - Umbenennen/Löschen liefert den alten Namen zurück; die Liste ordnet dann die Artikel neu zu.
 - Schreibaufträge an Supabase laufen strikt nacheinander (sonst könnten schnelle Änderungen vertauscht ankommen).

 📝 Last Change:
 - Offline zuerst mit gemerkten offenen Änderungen und Senden bei Netz (Audit 25.09.2026, M4).
 ------------------------------------------------------------------------
 */

import Combine
import Foundation

@MainActor
final class CategoryStore: ObservableObject {
    /// Offene, noch nicht gesendete Änderungen (übersteht Neustarts).
    private struct PendingSync: Codable {
        var dirty = false
        var deletedIds: [UUID] = []
    }
    @Published private(set) var categories: [CategoryDefinition] = CategoryDefinition.defaults
    @Published var errorMessage: String?

    private let repository: CategoryDefinitionsRepository?
    private let defaults: UserDefaults
    private var profileId: UUID?
    /// Letzter Schreibauftrag; neue warten darauf, damit Supabase die Änderungen in Tipp-Reihenfolge erhält.
    private var writeTask: Task<Void, Never>?
    private var reconnectSubscription: AnyCancellable?

    /// `reconnect`: meldet „wieder online“ → offene Änderungen senden.
    init(repository: CategoryDefinitionsRepository?, defaults: UserDefaults = .standard,
         reconnect: AnyPublisher<Bool, Never>? = nil) {
        self.repository = repository
        self.defaults = defaults
        reconnectSubscription = reconnect?
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in self?.scheduleSync() }
    }

    private func cacheKey(_ id: UUID) -> String { "categoryDefinitions.\(id.uuidString)" }
    private func pendingKey(_ id: UUID) -> String { "categoryDefinitions.pending.\(id.uuidString)" }

    private var pending: PendingSync {
        get {
            guard let profileId, let data = defaults.data(forKey: pendingKey(profileId)) else { return PendingSync() }
            return (try? JSONDecoder().decode(PendingSync.self, from: data)) ?? PendingSync()
        }
        set {
            guard let profileId else { return }
            defaults.set(try? JSONEncoder().encode(newValue), forKey: pendingKey(profileId))
        }
    }

    /// Nach der Anmeldung: Cache sofort; zuerst eigene offene Änderungen senden, dann Supabase übernehmen.
    /// Leeres Konto → Standard-Kategorien anlegen. Offline bleibt der lokale Stand (Audit M4).
    func load(profileId: UUID) async {
        self.profileId = profileId
        if let data = defaults.data(forKey: cacheKey(profileId)),
           let cached = try? JSONDecoder().decode([CategoryDefinition].self, from: data), !cached.isEmpty {
            categories = normalized(cached)
        }
        guard let repository else { return }
        if pending.dirty {
            scheduleSync()
            await writeTask?.value
            guard !pending.dirty else { return }              // offline: lokaler Stand bleibt maßgeblich
        }
        do {
            let remote = try await repository.fetch(profileId: profileId)
            if remote.isEmpty {
                categories = normalized(categories.isEmpty ? CategoryDefinition.defaults : categories)
                markDirty()
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
        var state = pending
        state.deletedIds.append(id)
        pending = state
        apply(categories.filter { $0.id != id }, changed: nil)
        UserLog.Data.categoryDeleted(name: target.name)
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

    /// Positionen neu durchzählen, „Sonstiges“ sicherstellen, Cache schreiben, zum Senden vormerken.
    private func apply(_ list: [CategoryDefinition], changed: [CategoryDefinition]?) {
        categories = normalized(list, renumber: true)
        saveCache()
        markDirty()
    }

    private func markDirty() {
        var state = pending
        state.dirty = true
        pending = state
        scheduleSync()
    }

    /// Sendet den ganzen lokalen Stand (Upsert) und die Löschungen. Nacheinander, damit Supabase die
    /// Änderungen in Tipp-Reihenfolge erhält. Ohne Netz bleibt alles vorgemerkt.
    private func scheduleSync() {
        guard let repository, let profileId, pending.dirty else { return }
        let previous = writeTask
        writeTask = Task {
            await previous?.value
            guard self.profileId == profileId, self.pending.dirty else { return }
            let snapshot = self.categories
            let deleted = self.pending.deletedIds
            do {
                try await repository.upsert(snapshot, profileId: profileId)
                for id in deleted { try await repository.delete(id: id) }
                // Nur zurücksetzen, wenn inzwischen nichts Neues dazukam.
                if self.categories == snapshot { self.pending = PendingSync() } else {
                    var state = self.pending
                    state.deletedIds.removeAll { deleted.contains($0) }
                    self.pending = state
                    self.scheduleSync()
                }
            } catch {
                logVoid(params: (action: "categories.sync.deferred", error: (error as NSError).localizedDescription))
                if SyncErrorClassifier.classify(error) == .permanent {
                    self.errorMessage = "Kategorien konnten nicht gespeichert werden."
                }
            }
        }
    }

    /// Nur für Tests: wartet, bis alle Schreibaufträge erledigt sind.
    func waitForWrites() async { await writeTask?.value }

    /// Abmelden: Standard-Kategorien, kein Profil – die Kategorien des Vorgängers dürfen nicht ins
    /// nächste Konto geschrieben werden (Audit H5).
    func resetLocal() {
        writeTask?.cancel()
        writeTask = nil
        if let profileId { defaults.removeObject(forKey: pendingKey(profileId)) }
        profileId = nil
        categories = CategoryDefinition.defaults
        errorMessage = nil
    }

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
