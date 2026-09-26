/*
 WatchAppEnvironment.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Setzt die Uhr-App zusammen (wie FamlistApp.init auf dem iPhone): Supabase-Client mit eigener Sitzung,
   WatchConnectivity, Sitzungsverwaltung, Sync-Koordinator. Verteilt die Nachrichten des iPhones.

 🔰 Notes for Beginners:
 - Unit-Tests laufen in der Uhr-App als Gastgeber: dann weder die echte Datenbank noch Supabase öffnen.
 - Nachrichten des iPhones: Artikel → nur per HLC übernehmen; Abmelden → Sitzung beenden, Speicher leeren;
   Kontext mit anderem Konto → ebenso, danach neu anmelden.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 4).
 ------------------------------------------------------------------------
 */

import Combine
import Foundation

@MainActor
final class WatchAppEnvironment: ObservableObject, WatchTransportDelegate {
    let transport: WatchConnectivityService
    let session: WatchSessionManager
    let sync: WatchSyncCoordinator
    private var sessionSubscription: AnyCancellable?

    init(processInfo: ProcessInfo = .processInfo) {
        let isUnitTestHost = processInfo.environment["XCTestConfigurationFilePath"] != nil
        let client = isUnitTestHost ? nil : SupabaseConfigLoader.load().flatMap(AppSupabaseClient.init(config:))
        let container = (isUnitTestHost ? PersistenceController.preview : .shared).container
        let transport = WatchConnectivityService()
        let session = WatchSessionManager(auth: client?.client.auth, transport: transport)

        let itemsRepository: ItemsRepository
        let remote: WatchRemoteSource?
        let catalogRemote: any ItemCatalogRepository
        if let client {
            itemsRepository = SupabaseItemsRepository(client: client, itemStore: SwiftDataItemStore(context: container.mainContext))
            remote = SupabaseWatchRemoteSource(client: client)
            catalogRemote = WatchCatalogRemote(client: client)
        } else {
            itemsRepository = PreviewItemsRepository()
            remote = nil
            catalogRemote = PreviewItemCatalogRepository()
        }
        let sync = WatchSyncCoordinator(
            container: container, itemsRepository: itemsRepository, remote: remote,
            catalog: OfflineItemCatalogRepository(remote: catalogRemote), transport: transport,
            hlcGenerator: HybridLogicalClockGenerator(defaults: .standard),
            userId: { [weak session] in session?.userId })

        self.transport = transport
        self.session = session
        self.sync = sync
        transport.delegate = self
        session.onAccountReset = { [weak sync] in sync?.reset() }
        // Frisch angemeldet: sofort abfragen, Artikelstamm laden.
        sessionSubscription = session.$state.removeDuplicates().sink { [weak sync] state in
            guard case .signedIn = state else { return }
            Task { @MainActor in
                await sync?.pull()
                await sync?.refreshCatalogIfDue(force: true)
            }
        }
    }

    /// App-Start: Verbindung zum iPhone aktivieren, Sitzung wiederherstellen oder anfragen.
    func start() async {
        transport.activate()
        await session.restore()
    }

    // MARK: - WatchTransportDelegate

    func transport(didReceive message: WatchMessage) async -> WatchMessage? {
        switch message {
        case .itemsChanged(let items):
            sync.mergeFromPhone(items)
        case .signedOut:
            await session.signOutLocally()
        case .requestSession, .sessionGrant, .sessionUnavailable:
            break                                          // Anfragen kommen nur von der Uhr
        }
        return nil
    }

    func transport(didReceiveContext context: WatchApplicationContext) {
        Task {
            await session.handle(context)
            if session.userId != nil, !context.changedListIds.isEmpty { await sync.pull() }
        }
    }

    func transportReachabilityChanged(_ isReachable: Bool) {
        Task { await session.reachabilityChanged(isReachable) }
    }
}
