/*
 WatchBridge.swift
 Famlist (nur iOS)
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Das iPhone als Partner der Apple Watch (Watch-Plan §2):
   - Anmeldung: Auf Bitte der Uhr holt das iPhone über die Edge Function watch-session einen einmaligen
     Code. Die Uhr bekommt damit eine EIGENE Sitzung; die Sitzung des iPhones bleibt unberührt.
   - Sofort-Weg: Artikel von der Uhr übernimmt das iPhone NUR per HLC (mergeRemote), ohne sie erneut an den
     Server zu senden – das tut die Uhr selbst. Eigene Änderungen und Änderungen anderer Mitglieder
     (Realtime, Delta) leitet das iPhone an die Uhr weiter, solange sie erreichbar ist.
   - Konto: Kontext mit der angemeldeten Konto-ID; Abmelden/Kontowechsel über den garantierten Weg.

 🔰 Notes for Beginners:
 - Keine UserLog-Einträge hier (nur ViewModels); technische Logs mit logVoid.
 - Ist die Uhr nicht erreichbar, geht nichts verloren: Beide Geräte gleichen sich über Supabase ab.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 4).
 ------------------------------------------------------------------------
 */

import Combine
import Foundation
import Supabase

@MainActor
final class WatchBridge: WatchTransportDelegate {
    private let transport: WatchTransport
    private let client: SupabaseClienting?
    private let itemStore: SwiftDataItemStore
    private let defaults: UserDefaults
    /// Artikel der Uhr wurden übernommen (Liste neu anzeigen, Zähler).
    var onItemsMerged: (@MainActor ([ItemModel]) -> Void)?

    static let lastUserKey = "watchBridge.lastUserId"
    private var accountSubscription: AnyCancellable?

    /// Antwort der Edge Function watch-session.
    private struct Grant: Decodable, Sendable {
        let tokenHash: String
        enum CodingKeys: String, CodingKey { case tokenHash = "token_hash" }
    }

    init(transport: WatchTransport, client: SupabaseClienting?, itemStore: SwiftDataItemStore,
         defaults: UserDefaults = .standard) {
        self.transport = transport
        self.client = client
        self.itemStore = itemStore
        self.defaults = defaults
    }

    // MARK: - Empfang

    func transport(didReceive message: WatchMessage) async -> WatchMessage? {
        switch message {
        case .requestSession:
            return await grantSession()
        case .itemsChanged(let items):
            mergeFromWatch(items)
            return nil
        case .sessionGrant, .sessionUnavailable, .signedOut:
            return nil                                    // nur Uhr-seitig von Bedeutung
        }
    }

    func transport(didReceiveContext context: WatchApplicationContext) {}

    func transportReachabilityChanged(_ isReachable: Bool) {}

    /// Einmaliger Anmelde-Code für die Uhr, nur wenn das iPhone angemeldet ist.
    func grantSession() async -> WatchMessage {
        guard let client, let userId = try? await client.auth.session.user.id else {
            return .sessionUnavailable(reason: .signedOut)
        }
        do {
            let grant: Grant = try await client.invokeFunction("watch-session")
            logVoid(params: (action: "watchBridge.grant", userId: userId))
            return .sessionGrant(tokenHash: grant.tokenHash, userId: userId)
        } catch FunctionsError.httpError(let code, _) where code == 429 {
            return .sessionUnavailable(reason: .rateLimited)
        } catch {
            logVoid(params: (action: "watchBridge.grant.error", error: error.localizedDescription))
            return .sessionUnavailable(reason: .failed)
        }
    }

    /// Artikel von der Uhr: nur übernehmen, wenn ihre HLC neuer ist. Nicht einreihen (die Uhr sendet selbst).
    func mergeFromWatch(_ items: [ItemModel]) {
        var merged: [ItemModel] = []
        for item in items {
            let result = (try? itemStore.mergeRemote(item, legacyImageKnown: false)) ?? .ignored
            if result != .ignored { merged.append(item) }
        }
        logVoid(params: (action: "watchBridge.received", count: items.count, merged: merged.count))
        guard !merged.isEmpty else { return }
        do { try itemStore.save() } catch {
            logVoid(params: (action: "watchBridge.merge.saveError", error: error.localizedDescription))
        }
        logVoid(params: (action: "watchBridge.merged", count: merged.count))
        onItemsMerged?(merged)
    }

    // MARK: - Senden

    /// Geänderte Artikel sofort an die Uhr (ohne Fotos), falls sie erreichbar ist.
    func forward(_ items: [ItemModel]) {
        guard !items.isEmpty else { return }
        logVoid(params: (action: "watchBridge.forward", count: items.count, reachable: transport.isReachable))
        guard transport.isReachable else { return }
        WatchMessage.itemBatches(items).forEach { transport.send($0, reply: nil) }
    }

    /// Von außen übernommene Artikel (Realtime, Delta) aus SwiftData lesen und weiterleiten; merkt die Liste
    /// außerdem im Kontext vor, damit die Uhr sie beim nächsten Aufwachen zuerst abfragt.
    func forwardStored(listId: UUID, itemIds: Set<String>) {
        let models = itemIds.compactMap { UUID(uuidString: $0) }
            .compactMap { try? itemStore.fetchItem(id: $0)?.toItemModel() }
        forward(models)
        transport.updateContext(WatchApplicationContext(userId: currentUserId, changedListIds: [listId]))
    }

    /// Anmelden, Abmelden oder Kontowechsel auf dem iPhone. Die Uhr erfährt es über den Kontext; beim
    /// Abmelden und beim Wechsel zusätzlich über den garantierten Weg (transferUserInfo).
    func accountDidChange(userId: UUID?) {
        let previous = defaults.string(forKey: Self.lastUserKey).flatMap(UUID.init(uuidString:))
        if let previous, previous != userId { transport.transfer(.signedOut) }
        defaults.set(userId?.uuidString, forKey: Self.lastUserKey)
        transport.updateContext(WatchApplicationContext(userId: userId))
        logVoid(params: (action: "watchBridge.account", signedIn: userId != nil, changed: previous != userId))
    }

    /// Anmelden bzw. Kontowechsel verfolgen. Nur `true` zählt: Beim App-Start ist die Anmeldung kurz `false`,
    /// bis die Sitzung wiederhergestellt ist – das darf die Uhr nicht abmelden. Abmelden meldet
    /// AppSessionViewModel.onSignOut ausdrücklich (FamlistApp).
    func observeSignIn(_ isAuthenticated: AnyPublisher<Bool, Never>, userId: @escaping @MainActor () -> UUID?) {
        accountSubscription = isAuthenticated.removeDuplicates().filter { $0 }.sink { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let id = userId() else { return }
                self.accountDidChange(userId: id)
            }
        }
    }

    private var currentUserId: UUID? {
        defaults.string(forKey: Self.lastUserKey).flatMap(UUID.init(uuidString:))
    }
}
