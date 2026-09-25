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

 📝 Last Change:
 - Senden, sobald wieder Netz da ist (`reconnect`).
 ------------------------------------------------------------------------
 */

import Combine
import Foundation

@MainActor
final class PriceBook: ObservableObject {
    private let repository: PricePointsRepository?
    private let defaults: UserDefaults
    private static let pendingKey = "pendingPricePoints"
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

    /// Alle Preise eines Artikels (Supabase + Warteschlange, ohne Doppelte), älteste zuerst.
    func history(itemName: String) async -> [PricePoint] {
        await flush()
        let key = PricePoint.key(for: itemName)
        let remote = (try? await repository?.history(itemKey: key)) ?? []
        let remoteIds = Set(remote.map(\.id))
        let local = pending.filter { $0.itemKey == key && !remoteIds.contains($0.id) }
        let all = (remote + local).sorted { $0.purchasedAt < $1.purchasedAt }
        if let last = all.last { remember(last) }
        return all
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
    }

    private func remember(_ point: PricePoint) {
        if let known = latestByItem[point.itemKey], known.purchasedAt > point.purchasedAt { return }
        latestByItem[point.itemKey] = point
    }
}
