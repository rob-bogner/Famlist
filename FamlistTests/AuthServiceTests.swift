/*
 AuthServiceTests.swift
 Created: 18.10.2025 | Updated: 18.10.2025
 
 Purpose: Unit tests for AuthService
 
 CHANGELOG:
 - 18.10.2025: Initial test cases for auth service methods
*/

import XCTest
@testable import Famlist

@MainActor
final class AuthServiceTests: XCTestCase {
    
    var mockClient: MockSupabaseClient!
    var authService: AuthService!
    
    override func setUp() {
        super.setUp()
        mockClient = MockSupabaseClient()
        authService = AuthService(client: mockClient)
    }
    
    override func tearDown() {
        authService = nil
        mockClient = nil
        super.tearDown()
    }
    
    func testSignInWithEmailOTP() async throws {
        // Given
        let email = "test@example.com"
        
        // When
        try await authService.signInWithEmailOTP(email: email)
        
        // Then
        XCTAssertTrue(mockClient.signInWithOTPCalled)
        XCTAssertEqual(mockClient.lastOTPEmail, email)
    }
    
    func testSignInWithEmailPassword() async throws {
        // Given
        let email = "test@example.com"
        let password = "password123"
        
        // When
        try await authService.signInWithEmailPassword(email: email, password: password)
        
        // Then
        XCTAssertTrue(mockClient.signInCalled)
        XCTAssertEqual(mockClient.lastEmail, email)
        XCTAssertEqual(mockClient.lastPassword, password)
    }
    
    func testSignUpWithEmailPassword() async throws {
        // Given
        let email = "newuser@example.com"
        let password = "newpassword123"
        
        // When
        try await authService.signUpWithEmailPassword(email: email, password: password)
        
        // Then
        XCTAssertTrue(mockClient.signUpCalled)
        XCTAssertEqual(mockClient.lastEmail, email)
        XCTAssertEqual(mockClient.lastPassword, password)
    }
    
    func testSignOut() async throws {
        // When
        try await authService.signOut()
        
        // Then
        XCTAssertTrue(mockClient.signOutCalled)
    }
}

// MARK: - Mock Client

@MainActor
class MockSupabaseClient: SupabaseClienting {
    var signInWithOTPCalled = false
    var signInCalled = false
    var signUpCalled = false
    var signOutCalled = false
    var lastOTPEmail: String?
    var lastEmail: String?
    var lastPassword: String?
    
    var auth: MockAuthClient {
        MockAuthClient(parent: self)
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
class MockAuthClient: AuthClient {
    weak var parent: MockSupabaseClient?
    
    init(parent: MockSupabaseClient) {
        self.parent = parent
    }
    
    var currentUser: User? {
        nil
    }
    
    var session: Session {
        get async throws {
            throw NSError(domain: "Mock", code: 401, userInfo: nil)
        }
    }
    
    func signInWithOTP(email: String, redirectTo: URL?) async throws {
        parent?.signInWithOTPCalled = true
        parent?.lastOTPEmail = email
    }
    
    func signIn(email: String, password: String) async throws {
        parent?.signInCalled = true
        parent?.lastEmail = email
        parent?.lastPassword = password
    }
    
    func signUp(email: String, password: String) async throws {
        parent?.signUpCalled = true
        parent?.lastEmail = email
        parent?.lastPassword = password
    }
    
    func signOut(scope: SignOutScope) async throws {
        parent?.signOutCalled = true
    }
    
    func session(from url: URL) async throws -> Session {
        throw NSError(domain: "Mock", code: 401, userInfo: nil)
    }
    
    var authStateChanges: AsyncStream<AuthStateChange> {
        AsyncStream { _ in }
    }
}

