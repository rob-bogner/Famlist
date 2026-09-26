/*
 WatchSessionManager.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Eigene Supabase-Sitzung der Uhr (Watch-Plan §2): wiederherstellen, beim iPhone einen Anmelde-Code
   erbitten und einlösen, abmelden, wenn das iPhone abmeldet oder das Konto wechselt.

 🔰 Notes for Beginners:
 - Die Sitzung liegt im Schlüsselbund der Uhr (Standard-Speicher von supabase-swift). Sie wird nie mit dem
   iPhone geteilt – Supabase würde sonst beide Sitzungen widerrufen.
 - Der Code kommt nur als Antwort auf sendMessage (nie über applicationContext, der bliebe liegen).
 - Das Konto des Codes muss zum Konto passen, das das iPhone meldet; sonst wird er verworfen.

 📝 Last Change:
 - Gespeicherte Sitzung gilt offline sofort; abgelehnte Sitzung → neuer Code ohne Datenverlust (Phase 5).
 ------------------------------------------------------------------------
 */

import Foundation
import Supabase

@MainActor
final class WatchSessionManager: ObservableObject {
    enum State: Equatable {
        /// Start: gespeicherte Sitzung wird geprüft.
        case checking
        /// Angemeldet (Konto-ID).
        case signedIn(UUID)
        /// Ohne Sitzung; das iPhone ist nicht erreichbar oder selbst abgemeldet.
        case needsPhone
        /// Code wird gerade beim iPhone angefragt und eingelöst.
        case pairing
    }

    @Published private(set) var state: State = .checking
    /// Konto gewechselt oder abgemeldet: lokalen Speicher leeren (WatchSyncCoordinator.reset).
    var onAccountReset: (@MainActor () async -> Void)?

    private let auth: AuthClient?
    private let transport: WatchTransport
    private let defaults: UserDefaults
    static let userKey = "watch.session.userId"
    /// Wartezeit nach „zu früh“ (Migration 023: 1 Code je 10 s).
    static let rateLimitDelay: UInt64 = 10_500_000_000

    init(auth: AuthClient?, transport: WatchTransport, defaults: UserDefaults = .standard) {
        self.auth = auth
        self.transport = transport
        self.defaults = defaults
    }

    var userId: UUID? {
        if case .signedIn(let id) = state { return id }
        return nil
    }

    /// App-Start: Eine gespeicherte Sitzung gilt sofort (auch offline – die Daten liegen lokal). Lehnt der
    /// Server sie später ab (widerrufen, abgelaufen), holt die Uhr einen neuen Code; Netzfehler ändern nichts.
    func restore() async {
        guard let auth else { state = .needsPhone; return }
        guard let stored = auth.currentSession else { await requestFromPhone(); return }
        state = .signedIn(stored.user.id)
        do {
            _ = try await auth.session                           // erneuert das Token bei Bedarf
        } catch is URLError {
            logVoid(params: (action: "watchSession.restore.offline", userId: stored.user.id))
        } catch {
            await sessionRejected()
            return
        }
        if let context = transport.receivedContext { await handle(context) }
    }

    /// Server lehnt die Sitzung ab: nur die Anmeldung verwerfen (Daten bleiben – gleiches Konto) und neu anfragen.
    private func sessionRejected() async {
        logVoid(params: ["action": "watchSession.rejected"])
        try? await auth?.signOut(scope: .local)
        state = .needsPhone
        await requestFromPhone()
    }

    /// Code beim iPhone anfragen und einlösen. Ohne erreichbares iPhone: `.needsPhone`.
    func requestFromPhone(retryAfterRateLimit: Bool = true) async {
        guard let auth, state != .pairing else { return }
        guard transport.isReachable else { state = .needsPhone; return }
        state = .pairing
        let answer = await withCheckedContinuation { continuation in
            transport.send(.requestSession) { continuation.resume(returning: $0) }
        }
        switch answer {
        case .success(.sessionGrant(let tokenHash, let userId)):
            await redeem(tokenHash: tokenHash, userId: userId, auth: auth)
        case .success(.sessionUnavailable(.rateLimited)) where retryAfterRateLimit:
            try? await Task.sleep(nanoseconds: Self.rateLimitDelay)
            state = .needsPhone
            await requestFromPhone(retryAfterRateLimit: false)
        default:
            logVoid(params: (action: "watchSession.request.failed", answer: String(describing: answer)))
            state = .needsPhone
        }
    }

    private func redeem(tokenHash: String, userId: UUID, auth: AuthClient) async {
        do {
            _ = try await auth.verifyOTP(tokenHash: tokenHash, type: .magiclink)
            let session = try await auth.session
            guard session.user.id == userId else {
                try? await auth.signOut(scope: .local)
                state = .needsPhone
                return
            }
            if let previous = storedUserId, previous != userId { await onAccountReset?() }
            defaults.set(userId.uuidString, forKey: Self.userKey)
            state = .signedIn(userId)
            logVoid(params: (action: "watchSession.signedIn", userId: userId))
        } catch {
            logVoid(params: (action: "watchSession.redeem.error", error: error.localizedDescription))
            state = .needsPhone
        }
    }

    /// iPhone meldet Abmelden oder Kontowechsel: Sitzung der Uhr beenden (nur diese) und Speicher leeren.
    func signOutLocally() async {
        try? await auth?.signOut(scope: .local)
        defaults.removeObject(forKey: Self.userKey)
        await onAccountReset?()
        state = .needsPhone
        logVoid(params: ["action": "watchSession.signedOut"])
    }

    /// Kontext des iPhones: anderes oder kein Konto → abmelden; neues Konto → gleich neu anfragen.
    func handle(_ context: WatchApplicationContext) async {
        guard let current = userId, context.userId != current else { return }
        await signOutLocally()
        if context.userId != nil { await requestFromPhone() }
    }

    /// iPhone wieder erreichbar: Anmeldung nachholen, falls sie fehlt.
    func reachabilityChanged(_ isReachable: Bool) async {
        guard isReachable, state == .needsPhone else { return }
        await requestFromPhone()
    }

    private var storedUserId: UUID? {
        defaults.string(forKey: Self.userKey).flatMap(UUID.init(uuidString:))
    }
}
