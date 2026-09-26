/*
 WatchConnectivityService.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - WatchTransport über WCSession (iPhone und Uhr). Aktiviert die Sitzung, wandelt Nachrichten in
   WatchMessage und reicht sie auf dem Main Actor an den Delegate weiter.

 🔰 Notes for Beginners:
 - WCSession ruft seinen Delegate auf einem Hintergrund-Thread auf. Deshalb werden die Werte dort zuerst
   in Sendable-Typen (Data, WatchMessage) umgewandelt und erst dann an den Main Actor übergeben.
 - Früh aktivieren (App-Start): Weckt die Uhr die iPhone-App im Hintergrund, muss die Sitzung stehen,
   bevor die Nachricht zugestellt wird.
 - Kein gekoppeltes Gerät / keine Uhr-App: `send` meldet einen Fehler, `transfer` und `updateContext`
   tun nichts.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 4).
 ------------------------------------------------------------------------
 */

import Foundation
import WatchConnectivity

@MainActor
final class WatchConnectivityService: NSObject, WatchTransport {
    weak var delegate: WatchTransportDelegate?
    private(set) var receivedContext: WatchApplicationContext?

    enum TransportError: Error {
        case notAvailable
        case notReachable
    }

    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    /// Startet die Sitzung (idempotent).
    func activate() {
        guard let session else { return }
        session.delegate = self
        if session.activationState != .activated { session.activate() }
        receivedContext = WatchApplicationContext(dictionary: session.receivedApplicationContext)
    }

    var isReachable: Bool { session?.isReachable ?? false }

    /// Ist das Gegenüber grundsätzlich vorhanden (iPhone: gekoppelte Uhr mit installierter App)?
    private var hasCounterpart: Bool {
        guard let session, session.activationState == .activated else { return false }
        #if os(iOS)
        return session.isPaired && session.isWatchAppInstalled
        #else
        return true
        #endif
    }

    func send(_ message: WatchMessage, reply: (@MainActor (Result<WatchMessage, Error>) -> Void)?) {
        guard let session, hasCounterpart else { reply?(.failure(TransportError.notAvailable)); return }
        guard session.isReachable else { reply?(.failure(TransportError.notReachable)); return }
        let dictionary: [String: Any]
        do { dictionary = try message.dictionary() } catch { reply?(.failure(error)); return }
        let callback = reply.map(ReplyCallback.init)
        if let callback {
            session.sendMessage(dictionary, replyHandler: { answer in
                let result = Result { try WatchMessage(dictionary: answer) }
                Task { @MainActor in callback.call(result) }
            }, errorHandler: { error in
                Task { @MainActor in callback.call(.failure(error)) }
            })
        } else {
            session.sendMessage(dictionary, replyHandler: nil) { error in
                logVoid(params: (action: "watch.send.error", error: error.localizedDescription))
            }
        }
    }

    func transfer(_ message: WatchMessage) {
        guard let session, hasCounterpart, let dictionary = try? message.dictionary() else { return }
        session.transferUserInfo(dictionary)
    }

    func updateContext(_ context: WatchApplicationContext) {
        guard let session, hasCounterpart, let dictionary = try? context.dictionary() else { return }
        do {
            try session.updateApplicationContext(dictionary)
        } catch {
            logVoid(params: (action: "watch.updateContext.error", error: error.localizedDescription))
        }
    }

    // MARK: - Empfang (Main Actor)

    private func deliver(_ message: WatchMessage, reply: ReplyHandlerBox?) async {
        let answer = await delegate?.transport(didReceive: message)
        guard let reply else { return }
        let dictionary = (try? (answer ?? .sessionUnavailable(reason: .failed)).dictionary()) ?? [:]
        reply.call(dictionary)
    }

    private func deliverContext(_ context: WatchApplicationContext) {
        receivedContext = context
        delegate?.transport(didReceiveContext: context)
    }
}

// MARK: - WCSessionDelegate (Hintergrund-Thread)

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        let context = WatchApplicationContext(dictionary: session.receivedApplicationContext)
        let reachable = session.isReachable
        logVoid(params: (action: "watch.activated", state: activationState.rawValue, error: error?.localizedDescription ?? "-"))
        Task { @MainActor in
            if let context { self.deliverContext(context) }
            self.delegate?.transportReachabilityChanged(reachable)
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Uhr gewechselt: Sitzung für die neue Uhr wieder aktivieren (Apple-Doku zu WCSessionDelegate).
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.delegate?.transportReachabilityChanged(reachable) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let decoded = Self.decode(message) else { return }
        Task { @MainActor in await self.deliver(decoded, reply: nil) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        let box = ReplyHandlerBox(replyHandler)
        guard let decoded = Self.decode(message) else {
            box.call((try? WatchMessage.sessionUnavailable(reason: .failed).dictionary()) ?? [:])
            return
        }
        Task { @MainActor in await self.deliver(decoded, reply: box) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let decoded = Self.decode(userInfo) else { return }
        Task { @MainActor in await self.deliver(decoded, reply: nil) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let context = WatchApplicationContext(dictionary: applicationContext) else { return }
        Task { @MainActor in self.deliverContext(context) }
    }

    nonisolated private static func decode(_ dictionary: [String: Any]) -> WatchMessage? {
        do {
            return try WatchMessage(dictionary: dictionary)
        } catch {
            logVoid(params: (action: "watch.decode.error", error: String(describing: error)))
            return nil
        }
    }
}

/// Antwort-Rückruf von WCSession; er darf von jedem Thread genau einmal aufgerufen werden.
private final class ReplyHandlerBox: @unchecked Sendable {
    private let handler: ([String: Any]) -> Void
    init(_ handler: @escaping ([String: Any]) -> Void) { self.handler = handler }
    func call(_ reply: [String: Any]) { handler(reply) }
}

/// Rückruf des Senders für die Antwort (nur auf dem Main Actor aufgerufen).
private final class ReplyCallback: @unchecked Sendable {
    let call: @MainActor (Result<WatchMessage, Error>) -> Void
    init(_ call: @escaping @MainActor (Result<WatchMessage, Error>) -> Void) { self.call = call }
}
