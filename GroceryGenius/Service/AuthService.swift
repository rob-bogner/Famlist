// MARK: - AuthService Protocol
// Swift 5.9+, iOS 17+

import Foundation
import AuthenticationServices

protocol AuthService: Sendable {
    var uid: String? { get }
    func signInAnonymously() async throws
    // Credential-based Apple sign-in with explicit rawNonce
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String) async throws
    func signOut() throws
}
