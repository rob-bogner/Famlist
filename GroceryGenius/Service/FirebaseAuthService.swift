// MARK: - FirebaseAuthService
// Implements AuthService using FirebaseAuth. No PII is persisted by this service.

import Foundation
@preconcurrency import FirebaseAuth
import AuthenticationServices

final class FirebaseAuthService: AuthService {
    init() {}
    var uid: String? { Auth.auth().currentUser?.uid }

    func signInAnonymously() async throws {
        _ = try await Auth.auth().signInAnonymously()
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String) async throws {
        guard let tokenData = credential.identityToken, let idTokenString = String(data: tokenData, encoding: .utf8) else {
            struct TokenError: LocalizedError { var errorDescription: String? { "Invalid Apple identity token." } }
            throw TokenError()
        }
        // Use modern API; do not provide fullName to avoid persisting PII
        let appleCred = OAuthProvider.appleCredential(withIDToken: idTokenString, rawNonce: rawNonce, fullName: nil)
        _ = try await Auth.auth().signIn(with: appleCred)
    }

    func signOut() throws { try Auth.auth().signOut() }
}
