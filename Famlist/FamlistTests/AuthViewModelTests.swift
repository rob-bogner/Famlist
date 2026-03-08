/*
 AuthViewModelTests.swift
 Created: 18.10.2025 | Updated: 08.03.2026

 Purpose: Unit tests for AuthViewModel

 CHANGELOG:
 - 18.10.2025: Initial test cases for auth view model
 - 08.03.2026: Fixed buttonText assertions to be locale-independent. The ViewModel uses
               String(localized:) which returns the German value in a de-locale test run
               and the English value in en-locale runs. Tests now check that the button
               text changes between modes rather than matching a hard-coded substring.
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

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(viewModel.email, "")
        XCTAssertEqual(viewModel.password, "")
        XCTAssertEqual(viewModel.authMode, .auto)
    }

    // MARK: - Form Validation

    func testIsFormValid_withValidEmail_noPasswordField() {
        // Given
        viewModel.email = "test@example.com"
        viewModel.showPasswordField = false

        // Then
        XCTAssertTrue(viewModel.isFormValid)
    }

    func testIsFormValid_withEmptyEmail() {
        // Given
        viewModel.email = ""

        // Then
        XCTAssertFalse(viewModel.isFormValid)
    }

    func testIsFormValid_withWhitespaceOnlyEmail() {
        // Given
        viewModel.email = "   "

        // Then
        XCTAssertFalse(viewModel.isFormValid, "Whitespace-only email must not be considered valid")
    }

    func testIsFormValid_passwordFieldRequired_noPassword() {
        // Given
        viewModel.email = "test@example.com"
        viewModel.showPasswordField = true
        viewModel.password = ""

        // Then
        XCTAssertFalse(viewModel.isFormValid)
    }

    func testIsFormValid_passwordFieldRequired_withPassword() {
        // Given
        viewModel.email = "test@example.com"
        viewModel.showPasswordField = true
        viewModel.password = "password123"

        // Then
        XCTAssertTrue(viewModel.isFormValid)
    }

    // MARK: - Password Field Visibility

    func testUpdatePasswordFieldVisibility_magicLink_hidesPasswordField() {
        // Given
        viewModel.authMode = .magicLink

        // When
        viewModel.updatePasswordFieldVisibility()

        // Then
        XCTAssertFalse(viewModel.showPasswordField)
    }

    func testUpdatePasswordFieldVisibility_emailPassword_showsPasswordField() {
        // Given
        viewModel.authMode = .emailPassword

        // When
        viewModel.updatePasswordFieldVisibility()

        // Then
        XCTAssertTrue(viewModel.showPasswordField)
    }

    // MARK: - Button Text

    /// Verifies that the button text differs between magicLink and emailPassword modes.
    /// The test is intentionally locale-independent: it does not assert a specific string
    /// (which is localised and changes with device language), only that the two modes
    /// produce distinct labels.
    func testButtonText_differsBetweenModes() {
        // Given
        viewModel.authMode = .magicLink
        viewModel.updatePasswordFieldVisibility()
        let magicLinkText = viewModel.buttonText

        viewModel.authMode = .emailPassword
        viewModel.updatePasswordFieldVisibility()
        let emailPasswordText = viewModel.buttonText

        // Then – the two modes must produce different button labels
        XCTAssertNotEqual(magicLinkText, emailPasswordText,
                          "Magic-link and email/password modes should use different button labels")
        XCTAssertFalse(magicLinkText.isEmpty, "Magic-link button text must not be empty")
        XCTAssertFalse(emailPasswordText.isEmpty, "Email/password button text must not be empty")
    }

    func testButtonText_autoMode_matchesMagicLinkWhenPasswordHidden() {
        // Given
        viewModel.authMode = .auto
        viewModel.showPasswordField = false
        let autoText = viewModel.buttonText

        viewModel.authMode = .magicLink
        viewModel.updatePasswordFieldVisibility()
        let magicLinkText = viewModel.buttonText

        // When the password field is hidden, .auto should produce the same label as .magicLink
        XCTAssertEqual(autoText, magicLinkText)
    }

    func testButtonText_autoMode_matchesEmailPasswordWhenPasswordShown() {
        // Given
        viewModel.authMode = .auto
        viewModel.showPasswordField = true
        let autoText = viewModel.buttonText

        viewModel.authMode = .emailPassword
        viewModel.updatePasswordFieldVisibility()
        let emailPasswordText = viewModel.buttonText

        // When the password field is visible, .auto should produce the same label as .emailPassword
        XCTAssertEqual(autoText, emailPasswordText)
    }
}
