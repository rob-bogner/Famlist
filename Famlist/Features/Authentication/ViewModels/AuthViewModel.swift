/*
 AuthViewModel.swift

 Famlist
 Created on: 18.10.2025
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - ViewModel managing auth form state, validation, and mode switching.

 🛠 Includes:
 - Form state (email, password, authMode, focus management)
 - Validation logic
 - Auth mode switching (magic link, email/password, auto)
 - Delegation to AppSessionViewModel for actual auth operations

 🔰 Notes for Beginners:
 - Extracted from AuthView to follow MVVM pattern and reduce view complexity.
 - This ViewModel is stateless regarding actual authentication (delegates to AppSessionViewModel).
 - Handles only UI concerns: form fields, validation, mode selection.

 📝 Last Change:
 - Extracted from AuthView.swift to reduce file size and improve testability.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides string operations.
import SwiftUI // SwiftUI provides FocusState.

/// ViewModel managing authentication form state and validation.
@MainActor
final class AuthViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var authMode: AuthMode = .auto
    @Published var showPasswordField: Bool = false
    
    // MARK: - Authentication Modes
    
    enum AuthMode: String, CaseIterable {
        case magicLink = "Magic Link"
        case emailPassword = "Email & Password"
        case auto = "Auto"
        
        var description: String {
            switch self {
            case .magicLink: return String(localized: "auth.mode.magicLink.description")
            case .emailPassword: return String(localized: "auth.mode.emailPassword.description")
            case .auto: return String(localized: "auth.mode.auto.description")
            }
        }
        
        static var defaultMode: AuthMode {
            #if targetEnvironment(simulator)
            return .emailPassword
            #else
            return .magicLink
            #endif
        }
    }
    
    // MARK: - Lifecycle
    
    init() {
        updatePasswordFieldVisibility()
    }
    
    // MARK: - Validation
    
    var isFormValid: Bool {
        let emailValid = !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let passwordValid = !showPasswordField || !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return emailValid && passwordValid
    }
    
    var buttonText: String {
        switch authMode {
        case .magicLink:
            return String(localized: "auth.signin.magiclink.button")
        case .emailPassword:
            return String(localized: "auth.signin.password.button")
        case .auto:
            return showPasswordField
                ? String(localized: "auth.signin.password.button")
                : String(localized: "auth.signin.magiclink.button")
        }
    }
    
    // MARK: - Mode Management
    
    func updatePasswordFieldVisibility() {
        switch authMode {
        case .magicLink:
            showPasswordField = false
        case .emailPassword:
            showPasswordField = true
        case .auto:
            showPasswordField = (AuthMode.defaultMode == .emailPassword)
        }
    }
    
    // MARK: - Auth Actions
    
    func signIn(using session: AppSessionViewModel) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedEmail.isEmpty else { return }
        
        switch authMode {
        case .magicLink:
            session.signInWithEmailOTP(email: trimmedEmail)
        case .emailPassword:
            guard !trimmedPassword.isEmpty else { return }
            session.signInWithEmailPassword(email: trimmedEmail, password: trimmedPassword)
        case .auto:
            if showPasswordField && !trimmedPassword.isEmpty {
                session.signInWithEmailPassword(email: trimmedEmail, password: trimmedPassword)
            } else {
                session.signInWithEmailOTP(email: trimmedEmail)
            }
        }
    }
    
    func signUp(using session: AppSessionViewModel) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedEmail.isEmpty && !trimmedPassword.isEmpty else { return }
        
        session.signUpWithEmailPassword(email: trimmedEmail, password: trimmedPassword)
    }
}

