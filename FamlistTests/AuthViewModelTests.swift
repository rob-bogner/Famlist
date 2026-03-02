/*
 AuthViewModelTests.swift
 Created: 18.10.2025 | Updated: 18.10.2025
 
 Purpose: Unit tests for AuthViewModel
 
 CHANGELOG:
 - 18.10.2025: Initial test cases for auth view model
*/

import XCTest
@testable import Famlist

@MainActor
final class AuthViewModelTests: XCTestCase {
    
    var viewModel: AuthViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = AuthViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testInitialState() {
        // Then
        XCTAssertEqual(viewModel.email, "")
        XCTAssertEqual(viewModel.password, "")
        XCTAssertEqual(viewModel.authMode, .auto)
    }
    
    func testIsFormValidWithValidEmail() {
        // Given
        viewModel.email = "test@example.com"
        viewModel.showPasswordField = false
        
        // Then
        XCTAssertTrue(viewModel.isFormValid)
    }
    
    func testIsFormValidWithEmptyEmail() {
        // Given
        viewModel.email = ""
        
        // Then
        XCTAssertFalse(viewModel.isFormValid)
    }
    
    func testIsFormValidWithPasswordRequired() {
        // Given
        viewModel.email = "test@example.com"
        viewModel.showPasswordField = true
        viewModel.password = ""
        
        // Then
        XCTAssertFalse(viewModel.isFormValid)
    }
    
    func testIsFormValidWithPasswordProvided() {
        // Given
        viewModel.email = "test@example.com"
        viewModel.showPasswordField = true
        viewModel.password = "password123"
        
        // Then
        XCTAssertTrue(viewModel.isFormValid)
    }
    
    func testUpdatePasswordFieldVisibilityForMagicLink() {
        // Given
        viewModel.authMode = .magicLink
        
        // When
        viewModel.updatePasswordFieldVisibility()
        
        // Then
        XCTAssertFalse(viewModel.showPasswordField)
    }
    
    func testUpdatePasswordFieldVisibilityForEmailPassword() {
        // Given
        viewModel.authMode = .emailPassword
        
        // When
        viewModel.updatePasswordFieldVisibility()
        
        // Then
        XCTAssertTrue(viewModel.showPasswordField)
    }
    
    func testButtonTextForMagicLink() {
        // Given
        viewModel.authMode = .magicLink
        
        // Then
        XCTAssertTrue(viewModel.buttonText.contains("Magic") || viewModel.buttonText.contains("magic"))
    }
    
    func testButtonTextForEmailPassword() {
        // Given
        viewModel.authMode = .emailPassword
        viewModel.showPasswordField = true
        
        // Then
        XCTAssertTrue(viewModel.buttonText.contains("Password") || viewModel.buttonText.contains("password"))
    }
}

