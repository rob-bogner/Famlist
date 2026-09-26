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
 - Hintergrund-Aktualisierung für Widgets (Watch-Plan Phase 6).
 ------------------------------------------------------------------------
 */

import Combine
import Foundation
import WatchKit

@MainActor
final class WatchAppEnvironment: ObservableObject, WatchTransportDelegate {
    let transport: WatchConnectivityService
    let session: WatchSessionManager
    let sync: WatchSyncCoordinator
    private var sessionSubscription: AnyCancellable?
    private var started = false
    /// Laufende Umgebung – für die Hintergrund-Aktualisierung (SwiftUI-Szene ruft sie ohne View-Kontext auf).
    private(set) static weak var current: WatchAppEnvironment?
    /// Wunschabstand der Hintergrund-Aktualisierung; watchOS teilt die tatsächlichen Läufe selbst zu.
    static let backgroundRefreshInterval: TimeInterval = 15 * 60

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
        Self.current = self
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

    /// App-Start: Verbindung zum iPhone aktivieren, Sitzung wiederherstellen oder anfragen (einmal).
    func start() async {
        guard !started else { return }
        started = true
        transport.activate()
        await session.restore()
    }

    /// Hintergrund-Aktualisierung (Komplikationen, Smart Stack): abfragen, senden, nächsten Lauf planen.
    /// Das ViewModel schreibt den Widget-Stand, sobald sich etwas geändert hat.
    static func performBackgroundRefresh() async {
        guard let environment = current else { return }
        await environment.start()
        await environment.sync.pull()
        await environment.sync.engine.resumeSync()
        environment.scheduleBackgroundRefresh()
    }

    /// Nächsten Hintergrundlauf anfragen (App verlässt den Vordergrund oder Lauf beendet).
    func scheduleBackgroundRefresh() {
        let date = Date().addingTimeInterval(Self.backgroundRefreshInterval)
        WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate: date, userInfo: nil) { error in
            if let error { logVoid(params: (action: "watch.scheduleRefresh.error", error: error.localizedDescription)) }
        }
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
