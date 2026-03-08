/*
 AuthServiceTests.swift
 Created: 18.10.2025 | Updated: 08.03.2026

 Purpose: Unit tests for AuthService

 CHANGELOG:
 - 18.10.2025: Initial test cases for auth service methods
 - 08.03.2026: Replaced MockAuthClient: AuthClient (illegal subclass of final class) with
               MockAuthClient: AuthClienting. signIn now returns a stub Session to match
               Supabase 2.31.2 API. MockSupabaseClient uses the new AuthClienting protocol.
*/

import XCTest
import Supabase
@testable import Famlist

@MainActor
final class AuthServiceTests: XCTestCase {

    var mockAuthClient: MockAuthClient!
    var mockClient: MockSupabaseClientForAuth!
    var authService: AuthService!

    override func setUp() {
        super.setUp()
        mockAuthClient = MockAuthClient()
        mockClient = MockSupabaseClientForAuth(auth: mockAuthClient)
        authService = AuthService(client: mockClient)
    }

    override func tearDown() {
        authService = nil
        mockClient = nil
        mockAuthClient = nil
        super.tearDown()
    }

    // MARK: - Tests

    func testSignInWithEmailOTP() async throws {
        // Given
        let email = "test@example.com"

        // When
        try await authService.signInWithEmailOTP(email: email)

        // Then
        XCTAssertTrue(mockAuthClient.signInWithOTPCalled)
        XCTAssertEqual(mockAuthClient.lastOTPEmail, email)
    }

    func testSignInWithEmailPassword() async throws {
        // Given
        let email = "test@example.com"
        let password = "password123"

        // When
        try await authService.signInWithEmailPassword(email: email, password: password)

        // Then
        XCTAssertTrue(mockAuthClient.signInCalled)
        XCTAssertEqual(mockAuthClient.lastEmail, email)
        XCTAssertEqual(mockAuthClient.lastPassword, password)
    }

    func testSignUpWithEmailPassword() async throws {
        // Given
        let email = "newuser@example.com"
        let password = "newpassword123"

        // When
        try await authService.signUpWithEmailPassword(email: email, password: password)

        // Then
        XCTAssertTrue(mockAuthClient.signUpCalled)
        XCTAssertEqual(mockAuthClient.lastEmail, email)
        XCTAssertEqual(mockAuthClient.lastPassword, password)
    }

    func testSignOut() async throws {
        // When
        try await authService.signOut()

        // Then
        XCTAssertTrue(mockAuthClient.signOutCalled)
    }
}

// MARK: - Shared Mock Helpers (reused in OnboardingServiceTests)

/// Minimal mock conforming to `AuthClienting`.
/// Does NOT subclass `AuthClient`, which is a `final class` in Supabase 2.x.
final class MockAuthClient: AuthClienting, @unchecked Sendable {

    // MARK: Spy flags
    var signInWithOTPCalled = false
    var signInCalled = false
    var signUpCalled = false
    var signOutCalled = false

    var lastOTPEmail: String?
    var lastEmail: String?
    var lastPassword: String?

    /// Optional user to return from `currentUser`; set in tests that need an authenticated user.
    var stubbedUser: User?

    // MARK: AuthClienting conformance

    var currentUser: User? { stubbedUser }

    var session: Session {
        get async throws {
            throw NSError(domain: "MockAuth", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "No session in mock"])
        }
    }

    var authStateChanges: AsyncStream<(event: AuthChangeEvent, session: Session?)> {
        AsyncStream { _ in }
    }

    func signInWithOTP(email: String, redirectTo: URL?) async throws {
        signInWithOTPCalled = true
        lastOTPEmail = email
    }

    @discardableResult
    func signIn(email: String, password: String) async throws -> Session {
        signInCalled = true
        lastEmail = email
        lastPassword = password
        return makeStubSession()
    }

    func signUp(email: String, password: String) async throws {
        signUpCalled = true
        lastEmail = email
        lastPassword = password
    }

    func signOut(scope: SignOutScope) async throws {
        signOutCalled = true
    }

    func session(from url: URL) async throws -> Session {
        throw NSError(domain: "MockAuth", code: 401, userInfo: nil)
    }

    // MARK: - Helpers

    private func makeStubSession() -> Session {
        let user = User(
            id: UUID(),
            appMetadata: [:],
            userMetadata: [:],
            aud: "authenticated",
            email: lastEmail,
            createdAt: Date(),
            updatedAt: Date()
        )
        return Session(
            accessToken: "stub-access-token",
            tokenType: "bearer",
            expiresIn: 3600,
            expiresAt: Date().timeIntervalSince1970 + 3600,
            refreshToken: "stub-refresh-token",
            user: user
        )
    }
}

/// Mock `SupabaseClienting` for auth-only tests.
@MainActor
final class MockSupabaseClientForAuth: SupabaseClienting {

    private let _auth: MockAuthClient

    init(auth: MockAuthClient) {
        self._auth = auth
    }

    var auth: any AuthClienting { _auth }

    var realtime: RealtimeClientV2 {
        fatalError("realtime not needed in auth tests")
    }

    func from(_ table: String) -> PostgrestQueryBuilder {
        fatalError("from(_:) not needed in auth tests")
    }

    func storageUpload(bucket: String, path: String, data: Data, contentType: String) async throws {
        fatalError("storageUpload not needed in auth tests")
    }

    func storageCreateSignedURL(bucket: String, path: String, expiresIn: Int) async throws -> String {
        fatalError("storageCreateSignedURL not needed in auth tests")
    }
}
