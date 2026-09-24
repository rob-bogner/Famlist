/*
 AppleSignInCoordinator.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Startet „Mit Apple anmelden“ über AuthenticationServices und liefert ID-Token + ungehashten Nonce.

 🔰 Notes for Beginners:
 - Apple bekommt den SHA-256 des Nonce, Supabase den ungehashten Nonce; so prüft Supabase,
   dass das Token zu genau dieser Anmeldung gehört.
 - Voraussetzung (nur Robert kann das): Capability „Sign in with Apple“ für com.roxo.famlist im
   Apple-Developer-Konto und der Provider „Apple“ im Supabase-Dashboard. Ohne das bricht Apple mit
   einem Fehler ab; die App zeigt dann „Anmeldung mit Apple ist fehlgeschlagen“.
 - Die Oberfläche ist der Design-Knopf aus SignIn.dc.html, nicht der System-Knopf.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 5).
 ------------------------------------------------------------------------
 */

import AuthenticationServices
import CryptoKit
import UIKit

@MainActor
final class AppleSignInCoordinator: NSObject {
    struct Result {
        let idToken: String
        let nonce: String
    }

    private var continuation: CheckedContinuation<Result?, Never>?
    private var nonce = ""

    /// Zeigt den Apple-Dialog. nil = abgebrochen oder fehlgeschlagen.
    func signIn() async -> Result? {
        nonce = Self.randomNonce()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    private func finish(_ result: Result?) {
        continuation?.resume(returning: result)
        continuation = nil
    }

    static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset[Int.random(in: 0..<charset.count, using: &generator)] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithAuthorization authorization: ASAuthorization) {
        let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        let token = credential?.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        Task { @MainActor in
            guard let token else { self.finish(nil); return }
            self.finish(Result(idToken: token, nonce: self.nonce))
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        logVoid(params: (action: "appleSignIn.error", error: (error as NSError).localizedDescription))
        Task { @MainActor in self.finish(nil) }
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}
