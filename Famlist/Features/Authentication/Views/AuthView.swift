/*
 AuthView.swift

 Famlist
 Created on: 07.09.2025
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Email OTP (magic link) and email/password sign-in screen.

 🛠 Includes:
 - Email TextField, password SecureField, mode picker, sign-in/sign-up buttons.
 - Error presentation from AppSessionViewModel.
 - Delegates form logic to AuthViewModel for better separation of concerns.

 🔰 Notes for Beginners:
 - After entering email and tapping Sign in, check inbox and open the magic link.
 - The app handles the deep link and completes login automatically.
 - Form state and validation are managed by AuthViewModel.

 📝 Last Change:
 - Refactored to use AuthViewModel for form state and validation.
 ------------------------------------------------------------------------
 */

import SwiftUI // Import SwiftUI for declarative UI.

/// Email-based authentication view using Supabase's OTP magic link or email/password.
struct AuthView: View {
    
    // MARK: - Environment & State
    
    @EnvironmentObject var session: AppSessionViewModel
    @StateObject private var viewModel = AuthViewModel()
    @State private var showErrorAlert: Bool = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email
        case password
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .center) {
            backgroundImage
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        logo
                        title
                        authModePicker
                        modeDescription
                        
                        #if DEBUG && targetEnvironment(simulator)
                        if viewModel.showPasswordField {
                            testAccountButtons
                        }
                        #endif
                        
                        emailField
                        
                        if viewModel.showPasswordField {
                            passwordField
                        }
                        
                        signInButton
                        
                        if viewModel.showPasswordField {
                            signUpButton
                        }
                        
                        errorMessage
                    }
                    .padding(20)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height, alignment: .center)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.updatePasswordFieldVisibility()
        }
        .onChange(of: viewModel.authMode) { _, _ in
            viewModel.updatePasswordFieldVisibility()
        }
        .onChange(of: session.errorMessage) { _, newValue in
            showErrorAlert = (newValue?.isEmpty == false)
        }
        .alert(String(localized: "auth.error.title"), isPresented: $showErrorAlert, actions: {
            Button(String(localized: "common.ok"), role: .cancel) {
                session.errorMessage = nil
            }
        }, message: {
            Text(session.errorMessage ?? "")
        })
    }
    
    // MARK: - View Components
    
    private var backgroundImage: some View {
        Image("famlistLoginBackground")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
    }
    
    private var logo: some View {
        Image("famlistLogo")
            .resizable()
            .scaledToFit()
            .frame(height: 80)
            .accessibilityHidden(true)
            .padding(.bottom, 8)
    }
    
    private var title: some View {
        Text(String(localized: "auth.title"))
            .font(.largeTitle.bold())
            .multilineTextAlignment(.center)
    }
    
    private var authModePicker: some View {
        Picker("Auth Mode", selection: $viewModel.authMode) {
            ForEach(AuthViewModel.AuthMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var modeDescription: some View {
        Text(viewModel.authMode.description)
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
    }
    
    #if DEBUG && targetEnvironment(simulator)
    private var testAccountButtons: some View {
        VStack(spacing: 8) {
            Text("Quick Test Accounts (Simulator Only)")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SimulatorAuthHelper.TestAccount.allCases, id: \.self) { account in
                        Button(account.description) {
                            let credentials = SimulatorAuthHelper.getCredentials(for: account)
                            viewModel.email = credentials.email
                            viewModel.password = credentials.password
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
    
    private var emailField: some View {
        TextField(String(localized: "auth.email.placeholder"), text: $viewModel.email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .focused($focusedField, equals: .email)
            .submitLabel(viewModel.showPasswordField ? .next : .go)
            .onSubmit {
                if viewModel.showPasswordField {
                    focusedField = .password
                } else {
                    viewModel.signIn(using: session)
                }
            }
            .padding(12)
            .background(Color.theme.background)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.theme.accent, lineWidth: 2))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private var passwordField: some View {
        SecureField(String(localized: "auth.password.placeholder"), text: $viewModel.password)
            .textContentType(.password)
            .focused($focusedField, equals: .password)
            .submitLabel(.go)
            .onSubmit {
                viewModel.signIn(using: session)
            }
            .padding(12)
            .background(Color.theme.background)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.theme.accent, lineWidth: 2))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private var signInButton: some View {
        Button {
            viewModel.signIn(using: session)
        } label: {
            HStack {
                if session.isLoading {
                    ProgressView()
                }
                Text(viewModel.buttonText)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.theme.accent)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(session.isLoading || !viewModel.isFormValid)
    }
    
    private var signUpButton: some View {
        Button {
            viewModel.signUp(using: session)
        } label: {
            HStack {
                if session.isLoading {
                    ProgressView()
                }
                Text(String(localized: "auth.signup.button"))
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.theme.background)
            .foregroundColor(Color.theme.accent)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.theme.accent, lineWidth: 2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(session.isLoading || !viewModel.isFormValid)
    }
    
    @ViewBuilder
    private var errorMessage: some View {
        if let error = session.errorMessage, !error.isEmpty {
            Text(error)
                .foregroundColor(.red)
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Previews

#Preview {
    let listVM = PreviewMocks.makeListViewModelWithSamples()
    let sessionVM = AppSessionViewModel(
        client: nil,
        profiles: PreviewProfilesRepository(),
        lists: PreviewListsRepository(),
        listViewModel: listVM
    )
    return AuthView()
        .environmentObject(sessionVM)
        .environmentObject(listVM)
}
