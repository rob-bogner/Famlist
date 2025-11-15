/*
 AuthView.swift

 GroceryGenius
 Created on: 07.09.2025
 Last updated on: 07.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Minimal email OTP (magic link) sign-in screen following the official Supabase Swift tutorial.

 🛠 Includes:
 - Email TextField, “Sign in” button calling supabase.auth.signInWithOTP with a deep-link redirect.
 - Error presentation from the AppSessionViewModel state.

 🔰 Notes for Beginners:
 - After you enter your email and tap Sign in, check your inbox on the device/emulator and open the magic link.
 - The app handles the deep link and completes login automatically.

 📝 Last Change:
 - Initial creation to support Supabase OTP auth per spec with MVVM binding and previews.
 ------------------------------------------------------------------------
 */

import SwiftUI // Import SwiftUI for declarative UI.

#if DEBUG && targetEnvironment(simulator)
/// Helper for providing pre-configured test accounts in simulator.
private enum SimulatorAuthHelper {
    enum TestAccount: String, CaseIterable {
        case developer = "developer@grocerygenius.app"
        case tester = "tester@grocerygenius.app"
        case demo = "demo@grocerygenius.app"
        
        var password: String {
            switch self {
            case .developer: return "DevTest123!"
            case .tester: return "TestUser456!"
            case .demo: return "DemoPass789!"
            }
        }
        
        var description: String {
            switch self {
            case .developer: return "Developer"
            case .tester: return "Tester"
            case .demo: return "Demo"
            }
        }
    }
    
    static func getCredentials(for account: TestAccount) -> (email: String, password: String) {
        return (email: account.rawValue, password: account.password)
    }
}
#endif

/// Email-based authentication view using Supabase's OTP magic link or email/password.
struct AuthView: View { // Declares a SwiftUI View.
    @EnvironmentObject var session: AppSessionViewModel // Read session VM to trigger sign-in and show errors.
    @State private var email: String = "" // Local state for the email text field.
    @State private var password: String = "" // Local state for the password text field.
    @State private var showErrorAlert: Bool = false // Controls alert presentation when an error occurs.
    @State private var authMode: AuthMode = .auto // Current authentication mode.
    @State private var showPasswordField: Bool = false // Whether to show password field.
    @FocusState private var focusedField: Field? // Tracks which field currently has focus.
    
    /// Enum to identify focusable fields for keyboard navigation.
    enum Field {
        case email
        case password
    }
    
    /// Authentication modes available in the app.
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
        
        /// Returns the optimal authentication mode for the current environment.
        static var defaultMode: AuthMode {
            #if targetEnvironment(simulator)
            return .emailPassword // Use password auth in simulator where magic links don't work.
            #else
            return .magicLink // Use magic links on real devices.
            #endif
        }
    }

    var body: some View { // Describes the view hierarchy.
        ZStack(alignment: .center) { // Background image + centered content
            Image("famlistLoginBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            GeometryReader { proxy in
                ScrollView { // Make content scrollable on smaller/larger devices and with keyboard.
                    VStack(spacing: 16) { // Vertical stack for inputs and actions.
                        Image("famlistLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 80)
                            .accessibilityHidden(true)
                            .padding(.bottom, 8)
                        Text(String(localized: "auth.title")) // Localized title.
                            .font(.largeTitle.bold()) // Prominent title styling.
                            .multilineTextAlignment(.center) // Center text alignment.
                        
                        // Auth mode selection
                        Picker("Auth Mode", selection: $authMode) {
                            ForEach(AuthMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented) // Use segmented control for mode selection.
                        .onChange(of: authMode) { _, newMode in
                            updatePasswordFieldVisibility() // Update UI based on selected mode.
                        }
                        
                        Text(authMode.description) // Show description of current auth mode.
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        #if DEBUG && targetEnvironment(simulator)
                        // Test account quick selection for simulator
                        if showPasswordField {
                            VStack(spacing: 8) {
                                Text("Quick Test Accounts (Simulator Only)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(SimulatorAuthHelper.TestAccount.allCases, id: \.self) { account in
                                            Button(account.description) {
                                                let credentials = SimulatorAuthHelper.getCredentials(for: account)
                                                email = credentials.email
                                                password = credentials.password
                                            }
                                            .font(.caption2)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.theme.accent.opacity(0.1))
                                            .foregroundColor(Color.theme.accent)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        #endif
                        
                        TextField(String(localized: "auth.email.placeholder"), text: $email) // Email text field bound to local state.
                            .textContentType(.emailAddress) // Hint keyboard/email autofill.
                            .keyboardType(.emailAddress) // Use email keyboard.
                            .textInputAutocapitalization(.never) // Do not autocapitalize emails.
                            .autocorrectionDisabled(true) // Disable autocorrect for emails.
                            .focused($focusedField, equals: .email) // Bind focus state to email field.
                            .submitLabel(showPasswordField ? .next : .go) // Show Next if password field is visible, Go otherwise.
                            .onSubmit { 
                                if showPasswordField {
                                    focusedField = .password // Move focus to password field.
                                } else {
                                    signIn() // Submit if no password field.
                                }
                            }
                            .padding(12) // Inner padding for tappable area.
                            .background(Color.theme.background) // Match app background color.
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.theme.accent, lineWidth: 2)) // Accent border.
                            .clipShape(RoundedRectangle(cornerRadius: 10)) // Rounded corners.
                        
                        if showPasswordField { // Show password field for email/password auth.
                            SecureField(String(localized: "auth.password.placeholder"), text: $password) // Password field.
                                .textContentType(.password) // Hint for password autofill.
                                .focused($focusedField, equals: .password) // Bind focus state to password field.
                                .submitLabel(.go) // Show Go button.
                                .onSubmit { signIn() } // Submit on Return key.
                                .padding(12) // Inner padding for tappable area.
                                .background(Color.theme.background) // Match app background color.
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.theme.accent, lineWidth: 2)) // Accent border.
                                .clipShape(RoundedRectangle(cornerRadius: 10)) // Rounded corners.
                        }
                        Button { // Sign in button action.
                            signIn()
                        } label: { // Button label view.
                            HStack { // Horizontal stack for label content.
                                if session.isLoading { ProgressView() } // Show spinner while signing in.
                                Text(buttonText) // Dynamic button text based on auth mode.
                                    .font(.headline) // Emphasized font.
                            }
                            .frame(maxWidth: .infinity) // Make button expand full width.
                            .padding(.vertical, 12) // Vertical padding for comfortable tap target.
                            .background(Color.theme.accent) // Accent background.
                            .foregroundColor(.white) // White text color.
                            .clipShape(RoundedRectangle(cornerRadius: 12)) // Rounded rectangle button.
                        }
                        .disabled(session.isLoading || !isFormValid) // Disable while request in progress or form invalid.
                        
                        if showPasswordField { // Show sign-up option for email/password mode.
                            Button { // Sign up button action.
                                signUp()
                            } label: { // Button label view.
                                HStack { // Horizontal stack for label content.
                                    if session.isLoading { ProgressView() } // Show spinner while signing up.
                                    Text(String(localized: "auth.signup.button")) // Sign up button text.
                                        .font(.subheadline) // Smaller font than primary button.
                                }
                                .frame(maxWidth: .infinity) // Make button expand full width.
                                .padding(.vertical, 12) // Vertical padding for comfortable tap target.
                                .background(Color.theme.background) // Background color.
                                .foregroundColor(Color.theme.accent) // Accent text color.
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.accent, lineWidth: 2)) // Accent border.
                                .clipShape(RoundedRectangle(cornerRadius: 12)) // Rounded rectangle button.
                            }
                            .disabled(session.isLoading || !isFormValid) // Disable while request in progress or form invalid.
                        }
                        if let error = session.errorMessage, !error.isEmpty { // If an error message is present, show it inline.
                            Text(error) // Show readable error.
                                .foregroundColor(.red) // Red color to indicate error.
                                .font(.footnote) // Smaller font.
                                .multilineTextAlignment(.center) // Center align.
                        }
                        // Spacer() // Push content upwards slightly. <-- Removed as per instructions.
                    }
                    .padding(20) // Outer padding to keep content away from edges.
                    .frame(maxWidth: 520) // Constrain content width for iPad readability.
                    .frame(maxWidth: .infinity) // Center horizontally.
                    .frame(minHeight: proxy.size.height, alignment: .center) // Vertically center within visible height.
                }
                .scrollIndicators(.hidden) // Hide scroll indicators for a cleaner look.
                .scrollDismissesKeyboard(.interactively) // Better keyboard handling.
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            updatePasswordFieldVisibility() // Set initial password field visibility based on auto-detected mode.
        }
        .onChange(of: session.errorMessage) { _, newValue in // Observe error changes.
            showErrorAlert = (newValue?.isEmpty == false) // Toggle alert when a new error appears.
        }
        .alert(String(localized: "auth.error.title"), isPresented: $showErrorAlert, actions: { // Present an alert for errors.
            Button(String(localized: "common.ok"), role: .cancel) { session.errorMessage = nil } // Dismiss action clears the error.
        }, message: { // Alert message content.
            Text(session.errorMessage ?? "") // Show the current error message.
        })
    }
    
    /// Computed property for button text based on current auth mode.
    private var buttonText: String {
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
    
    /// Computed property to check if the form is valid for submission.
    private var isFormValid: Bool {
        let emailValid = !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let passwordValid = !showPasswordField || !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return emailValid && passwordValid
    }
    
    /// Updates password field visibility based on current auth mode.
    private func updatePasswordFieldVisibility() {
        switch authMode {
        case .magicLink:
            showPasswordField = false
        case .emailPassword:
            showPasswordField = true
        case .auto:
            showPasswordField = (AuthMode.defaultMode == .emailPassword) // Show password field if auto-detected mode requires it.
        }
    }
    
    /// Handles sign-in action based on current auth mode.
    private func signIn() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedEmail.isEmpty else { return }
        
        switch authMode {
        case .magicLink:
            session.signInWithEmailOTP(email: trimmedEmail) // Use magic link authentication.
        case .emailPassword:
            guard !trimmedPassword.isEmpty else { return }
            session.signInWithEmailPassword(email: trimmedEmail, password: trimmedPassword) // Use email/password authentication.
        case .auto:
            if showPasswordField && !trimmedPassword.isEmpty {
                session.signInWithEmailPassword(email: trimmedEmail, password: trimmedPassword) // Use email/password if password field is shown.
            } else {
                session.signInWithEmailOTP(email: trimmedEmail) // Fallback to magic link.
            }
        }
    }
    
    /// Handles sign-up action for email/password mode.
    private func signUp() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedEmail.isEmpty && !trimmedPassword.isEmpty else { return }
        
        session.signUpWithEmailPassword(email: trimmedEmail, password: trimmedPassword) // Create new account with email/password.
    }
}

#Preview {
    // Preview showing the sign-in form with a mocked session VM.
    let listVM = PreviewMocks.makeListViewModelWithSamples() // Create a preview list VM (not used here, but kept for consistency across app previews).
    let sessionVM = AppSessionViewModel(client: nil, // No real client for previews.
                                        profiles: PreviewProfilesRepository(), // Preview profiles repo.
                                        lists: PreviewListsRepository(), // Preview lists repo.
                                        listViewModel: listVM) // Inject list VM.
    return AuthView() // Render the AuthView.
        .environmentObject(sessionVM) // Inject mocked session VM.
        .environmentObject(listVM) // Inject list VM in environment for downstream views if needed.
}
