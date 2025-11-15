/*
 OnboardingServiceTests.swift
 Created: 18.10.2025 | Updated: 18.10.2025
 
 Purpose: Unit tests for OnboardingService
 
 CHANGELOG:
 - 18.10.2025: Initial test cases for onboarding service
*/

import XCTest
@testable import Famlist

@MainActor
final class OnboardingServiceTests: XCTestCase {
    
    var mockClient: MockSupabaseClientForOnboarding!
    var mockProfilesRepo: MockProfilesRepository!
    var onboardingService: OnboardingService!
    
    override func setUp() {
        super.setUp()
        mockClient = MockSupabaseClientForOnboarding()
        mockProfilesRepo = MockProfilesRepository()
        onboardingService = OnboardingService(client: mockClient, profiles: mockProfilesRepo)
    }
    
    override func tearDown() {
        onboardingService = nil
        mockProfilesRepo = nil
        mockClient = nil
        super.tearDown()
    }
    
    func testCreateProfileForNewUser() async throws {
        // Given
        let testUserId = UUID()
        mockClient.mockUserId = testUserId
        
        // When
        let profile = try await onboardingService.createProfileForNewUser()
        
        // Then
        XCTAssertTrue(mockProfilesRepo.upsertCalled)
        XCTAssertEqual(mockProfilesRepo.lastAuthUserId, testUserId)
        XCTAssertNotNil(mockProfilesRepo.lastPublicId)
        XCTAssertEqual(mockProfilesRepo.lastPublicId?.count, 8) // Public ID should be 8 characters
        XCTAssertNotNil(profile)
    }
    
    func testGeneratedPublicIdIsAlphanumeric() async throws {
        // Given
        let testUserId = UUID()
        mockClient.mockUserId = testUserId
        
        // When
        _ = try await onboardingService.createProfileForNewUser()
        
        // Then
        let publicId = mockProfilesRepo.lastPublicId!
        let allowedCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let publicIdCharSet = CharacterSet(charactersIn: publicId)
        XCTAssertTrue(allowedCharacters.isSuperset(of: publicIdCharSet))
    }
}

// MARK: - Mock Client for Onboarding

@MainActor
class MockSupabaseClientForOnboarding: SupabaseClienting {
    var mockUserId: UUID?
    
    var auth: MockAuthClientForOnboarding {
        MockAuthClientForOnboarding(userId: mockUserId)
    }
    
    var realtime: RealtimeClientV2 {
        fatalError("Not implemented for tests")
    }
    
    func from(_ table: String) -> PostgrestQueryBuilder {
        fatalError("Not implemented for tests")
    }
    
    func storageUpload(bucket: String, path: String, data: Data, contentType: String) async throws {
        fatalError("Not implemented for tests")
    }
    
    func storageCreateSignedURL(bucket: String, path: String, expiresIn: Int) async throws -> String {
        fatalError("Not implemented for tests")
    }
}

@MainActor
class MockAuthClientForOnboarding: AuthClient {
    let userId: UUID?
    
    init(userId: UUID?) {
        self.userId = userId
    }
    
    var currentUser: User? {
        if let userId {
            return User(id: userId, email: "test@example.com")
        }
        return nil
    }
    
    var session: Session {
        get async throws {
            throw NSError(domain: "Mock", code: 401, userInfo: nil)
        }
    }
    
    func signInWithOTP(email: String, redirectTo: URL?) async throws {}
    func signIn(email: String, password: String) async throws {}
    func signUp(email: String, password: String) async throws {}
    func signOut(scope: SignOutScope) async throws {}
    func session(from url: URL) async throws -> Session {
        throw NSError(domain: "Mock", code: 401, userInfo: nil)
    }
    
    var authStateChanges: AsyncStream<AuthStateChange> {
        AsyncStream { _ in }
    }
}

// MARK: - Mock Profiles Repository

@MainActor
class MockProfilesRepository: ProfilesRepository {
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

// MARK: - User Extension for Mock

extension User {
    init(id: UUID, email: String) {
        // This is a simplified mock initialization
        // In real code, User would have more fields
        self.init(
            id: id,
            appMetadata: [:],
            userMetadata: [:],
            aud: "authenticated",
            confirmationSentAt: nil,
            recoverySentAt: nil,
            emailChangeSentAt: nil,
            newEmail: nil,
            invitedAt: nil,
            actionLink: nil,
            email: email,
            phone: nil,
            createdAt: Date(),
            confirmedAt: nil,
            emailConfirmedAt: nil,
            phoneConfirmedAt: nil,
            lastSignInAt: nil,
            role: nil,
            updatedAt: Date(),
            identities: nil,
            factors: nil
        )
    }
}

