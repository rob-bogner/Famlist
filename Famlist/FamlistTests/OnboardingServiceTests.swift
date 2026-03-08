/*
 OnboardingServiceTests.swift
 Created: 18.10.2025 | Updated: 08.03.2026

 Purpose: Unit tests for OnboardingService

 CHANGELOG:
 - 18.10.2025: Initial test cases for onboarding service
 - 08.03.2026: Replaced MockAuthClientForOnboarding: AuthClient (illegal subclass of final class)
               with a lightweight mock conforming to AuthClienting. Removed the User convenience
               extension whose memberwise parameters diverged from Supabase 2.31.2.
*/

import XCTest
import Supabase
@testable import Famlist

@MainActor
final class OnboardingServiceTests: XCTestCase {

    var mockAuthClient: MockAuthClientForOnboarding!
    var mockClient: MockSupabaseClientForOnboarding!
    var mockProfilesRepo: MockProfilesRepository!
    var onboardingService: OnboardingService!

    override func setUp() {
        super.setUp()
        mockAuthClient = MockAuthClientForOnboarding()
        mockClient = MockSupabaseClientForOnboarding(auth: mockAuthClient)
        mockProfilesRepo = MockProfilesRepository()
        onboardingService = OnboardingService(client: mockClient, profiles: mockProfilesRepo)
    }

    override func tearDown() {
        onboardingService = nil
        mockProfilesRepo = nil
        mockClient = nil
        mockAuthClient = nil
        super.tearDown()
    }

    // MARK: - Tests

    func testCreateProfileForNewUser() async throws {
        // Given
        let testUserId = UUID()
        mockAuthClient.stubbedUserId = testUserId

        // When
        let profile = try await onboardingService.createProfileForNewUser()

        // Then
        XCTAssertTrue(mockProfilesRepo.upsertCalled)
        XCTAssertEqual(mockProfilesRepo.lastAuthUserId, testUserId)
        XCTAssertNotNil(mockProfilesRepo.lastPublicId)
        XCTAssertEqual(mockProfilesRepo.lastPublicId?.count, 8, "Public ID should be 8 characters")
        XCTAssertNotNil(profile)
    }

    func testGeneratedPublicIdIsAlphanumeric() async throws {
        // Given
        let testUserId = UUID()
        mockAuthClient.stubbedUserId = testUserId

        // When
        _ = try await onboardingService.createProfileForNewUser()

        // Then
        let publicId = try XCTUnwrap(mockProfilesRepo.lastPublicId)
        let allowedCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let publicIdCharSet = CharacterSet(charactersIn: publicId)
        XCTAssertTrue(allowedCharacters.isSuperset(of: publicIdCharSet),
                      "Public ID '\(publicId)' contains characters outside A-Z 0-9")
    }

    func testCreateProfileFailsWhenNoAuthUser() async {
        // Given – no user set on the mock auth client; session also throws
        mockAuthClient.stubbedUserId = nil

        // When / Then
        do {
            _ = try await onboardingService.createProfileForNewUser()
            XCTFail("Expected an error when no authenticated user is present")
        } catch {
            // Expected path: OnboardingService must throw when neither
            // currentUser nor session are available.
            XCTAssertNotNil(error)
        }
    }
}

// MARK: - Mock AuthClienting for Onboarding

/// Lightweight `AuthClienting` mock — does NOT subclass `final class AuthClient`.
@MainActor
final class MockAuthClientForOnboarding: AuthClienting {

    /// Set this to provide a `currentUser` to `OnboardingService`.
    var stubbedUserId: UUID?

    var currentUser: User? {
        guard let id = stubbedUserId else { return nil }
        return User(
            id: id,
            appMetadata: [:],
            userMetadata: [:],
            aud: "authenticated",
            email: "test@example.com",
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    var session: Session {
        get async throws {
            throw NSError(domain: "MockAuth", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "No session in mock"])
        }
    }

    var authStateChanges: AsyncStream<(event: AuthChangeEvent, session: Session?)> {
        AsyncStream { _ in }
    }

    func signInWithOTP(email: String, redirectTo: URL?) async throws {}
    func signIn(email: String, password: String) async throws -> Session {
        throw NSError(domain: "MockAuth", code: 401, userInfo: nil)
    }
    func signUp(email: String, password: String) async throws {}
    func signOut(scope: SignOutScope) async throws {}
    func session(from url: URL) async throws -> Session {
        throw NSError(domain: "MockAuth", code: 401, userInfo: nil)
    }
}

// MARK: - Mock SupabaseClienting for Onboarding

@MainActor
final class MockSupabaseClientForOnboarding: SupabaseClienting {

    private let _auth: MockAuthClientForOnboarding

    init(auth: MockAuthClientForOnboarding) {
        self._auth = auth
    }

    var auth: any AuthClienting { _auth }

    var realtime: RealtimeClientV2 {
        fatalError("realtime not needed in onboarding tests")
    }

    func from(_ table: String) -> PostgrestQueryBuilder {
        fatalError("from(_:) not needed in onboarding tests")
    }

    func storageUpload(bucket: String, path: String, data: Data, contentType: String) async throws {
        fatalError("storageUpload not needed in onboarding tests")
    }

    func storageCreateSignedURL(bucket: String, path: String, expiresIn: Int) async throws -> String {
        fatalError("storageCreateSignedURL not needed in onboarding tests")
    }
}

// MARK: - Mock ProfilesRepository

@MainActor
final class MockProfilesRepository: ProfilesRepository {

    var upsertCalled = false
    var lastAuthUserId: UUID?
    var lastPublicId: String?

    func upsertProfile(authUserId: UUID, publicId: String) async throws {
        upsertCalled = true
        lastAuthUserId = authUserId
        lastPublicId = publicId
    }

    func myProfile() async throws -> Profile {
        Profile(
            id: lastAuthUserId ?? UUID(),
            publicId: lastPublicId ?? "TEST1234",
            username: nil,
            fullName: nil,
            avatarUrl: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }

    func profileByPublicId(_ publicId: String) async throws -> Profile? {
        nil
    }
}
