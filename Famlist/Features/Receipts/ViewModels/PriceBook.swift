/*
 PriceBook.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Speichert Preispunkte (auch offline) und liefert den Preisverlauf eines Artikels.

 🔰 Notes for Beginners:
 - Offline-First: Neue Preise landen zuerst in einer Warteschlange (UserDefaults) und werden dann an
   Supabase geschickt. Klappt das nicht, bleiben sie in der Warteschlange und werden gesendet,
   sobald wieder Netz da ist (bzw. beim nächsten Speichern oder Öffnen des Preisverlaufs).
 - Der Preisverlauf zeigt Supabase-Daten plus noch nicht gesendete Preise.
 - Offline-First beim Lesen: `localHistory` liefert sofort die zuletzt geladenen Punkte (gespeichert
   in UserDefaults) plus Warteschlange; `history` lädt danach vom Server.

 📝 Last Change:
 - Verlauf lokal vorhalten und sofort zeigen; manuelle Preise aus „Artikel bearbeiten“ hier statt in
   der View; Abmelden leert alles (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Combine
import Foundation

@MainActor
final class PriceBook: ObservableObject {
    private let repository: PricePointsRepository?
    private let defaults: UserDefaults
    private static let pendingKey = "pendingPricePoints"
    private static let historyKey = "priceHistoryCache"
    private var reconnectSubscription: AnyCancellable?
    /// Letzter bekannter Preis je Artikel (item_key) – füllt den Link „Preisverlauf“ sofort, ohne Netz.
    private var latestByItem: [String: PricePoint] = [:]

    /// `reconnect`: meldet „wieder online“ (ConnectivityMonitor) → Warteschlange sofort senden.
    init(repository: PricePointsRepository?, defaults: UserDefaults = .standard,
         reconnect: AnyPublisher<Bool, Never>? = nil) {
        self.repository = repository
        self.defaults = defaults
        reconnectSubscription = reconnect?
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in Task { await self?.flush() } }
    }

    private(set) var pending: [PricePoint] {
        get {
            guard let data = defaults.data(forKey: Self.pendingKey) else { return [] }
            return (try? JSONDecoder().decode([PricePoint].self, from: data)) ?? []
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.pendingKey) }
    }

    /// „Preise speichern“: sofort lokal merken, dann senden. Liefert die Anzahl gespeicherter Preise.
    @discardableResult
    func save(_ points: [PricePoint]) async -> Int {
        guard !points.isEmpty else { return 0 }
        pending += points
        points.forEach(remember)
        UserLog.Data.pricesSaved(count: points.count)
        await flush()
        return points.count
    }

    /// Sendet die Warteschlange; bei Fehler bleibt sie erhalten.
    func flush() async {
        let queue = pending
        guard let repository, !queue.isEmpty else { return }
        do {
            try await repository.insert(queue)
            let sent = Set(queue.map(\.id))
            pending = pending.filter { !sent.contains($0.id) }
        } catch {
            logVoid(params: (action: "priceBook.flush.error", count: queue.count,
                             error: (error as NSError).localizedDescription))
        }
    }

    /// Zuletzt geladene Verläufe je Artikel (für die Offline-Anzeige).
    private var historyCache: [String: [PricePoint]] {
        get {
            guard let data = defaults.data(forKey: Self.historyKey) else { return [:] }
            return (try? JSONDecoder().decode([String: [PricePoint]].self, from: data)) ?? [:]
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.historyKey) }
    }

    /// Sofort und ohne Netz: zuletzt geladener Verlauf plus Warteschlange, älteste zuerst.
    func localHistory(itemName: String) -> [PricePoint] {
        let key = PricePoint.key(for: itemName)
        return merged(historyCache[key] ?? [], key: key)
    }

    /// Verlauf vom Server (plus Warteschlange). Ohne Netz: die lokale Kopie.
    func history(itemName: String) async -> [PricePoint] {
        await flush()
        let key = PricePoint.key(for: itemName)
        guard let repository, let remote = try? await repository.history(itemKey: key) else {
            return localHistory(itemName: itemName)
        }
        var cache = historyCache
        cache[key] = remote
        historyCache = cache
        let all = merged(remote, key: key)
        if let last = all.last { remember(last) }
        return all
    }

    private func merged(_ confirmed: [PricePoint], key: String) -> [PricePoint] {
        let ids = Set(confirmed.map(\.id))
        let local = pending.filter { $0.itemKey == key && !ids.contains($0.id) }
        return (confirmed + local).sorted { $0.purchasedAt < $1.purchasedAt }
    }

    /// Neuer Preis aus „Artikel bearbeiten“ → Preispunkt von heute. Laden = Listenname: In Famlist
    /// heißen Listen nach dem Laden („Edeka“, „Rewe“), die Kategorien folgen dem Ladenweg.
    func recordManualPrice(itemName: String, price: Double, store: String) {
        let point = PricePoint(itemName: itemName, storeName: store, purchasedAt: Date(),
                               price: PriceHistoryViewModel.decimal(price))
        Task { await save([point]) }
    }

    /// Letzter Preis aus Zwischenspeicher oder lokaler Warteschlange (synchron, kein Netzwerk).
    func cachedLatest(itemName: String) -> PricePoint? {
        let key = PricePoint.key(for: itemName)
        let queued = pending.filter { $0.itemKey == key }.max { $0.purchasedAt < $1.purchasedAt }
        return [latestByItem[key], queued].compactMap { $0 }.max { $0.purchasedAt < $1.purchasedAt }
    }

    /// Abmelden: Warteschlange und Zwischenspeicher gehören zum abgemeldeten Konto (sonst würden die
    /// Preise später mit der ID des NÄCHSTEN Nutzers gesendet, Audit H5).
    func clearLocal() {
        pending = []
        latestByItem = [:]
        defaults.removeObject(forKey: Self.historyKey)
    }

    private func remember(_ point: PricePoint) {
        if let known = latestByItem[point.itemKey], known.purchasedAt > point.purchasedAt { return }
        latestByItem[point.itemKey] = point
    }
}
