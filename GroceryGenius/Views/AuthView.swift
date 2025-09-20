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

/// Email-based authentication view using Supabase's OTP magic link.
struct AuthView: View { // Declares a SwiftUI View.
    @EnvironmentObject var session: AppSessionViewModel // Read session VM to trigger sign-in and show errors.
    @State private var email: String = "" // Local state for the email text field.
    @State private var showErrorAlert: Bool = false // Controls alert presentation when an error occurs.

    var body: some View { // Describes the view hierarchy.
        ZStack(alignment: .top) { // Background image + content
            Image("famlistLoginBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
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
                TextField(String(localized: "auth.email.placeholder"), text: $email) // Email text field bound to local state.
                    .textContentType(.emailAddress) // Hint keyboard/email autofill.
                    .keyboardType(.emailAddress) // Use email keyboard.
                    .textInputAutocapitalization(.never) // Do not autocapitalize emails.
                    .autocorrectionDisabled(true) // Disable autocorrect for emails.
                    .padding(12) // Inner padding for tappable area.
                    .background(Color.theme.background) // Match app background color.
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.theme.accent, lineWidth: 2)) // Accent border.
                    .clipShape(RoundedRectangle(cornerRadius: 10)) // Rounded corners.
                Button { // Sign in button action.
                    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines) // Normalize input.
                    guard !trimmed.isEmpty else { return } // Ignore empty emails.
                    session.signInWithEmailOTP(email: trimmed) // Trigger OTP email flow via VM.
                } label: { // Button label view.
                    HStack { // Horizontal stack for label content.
                        if session.isLoading { ProgressView() } // Show spinner while signing in.
                        Text(String(localized: "auth.signin.button")) // Localized button text.
                            .font(.headline) // Emphasized font.
                    }
                    .frame(maxWidth: .infinity) // Make button expand full width.
                    .padding(.vertical, 12) // Vertical padding for comfortable tap target.
                    .background(Color.theme.accent) // Accent background.
                    .foregroundColor(.white) // White text color.
                    .clipShape(RoundedRectangle(cornerRadius: 12)) // Rounded rectangle button.
                }
                .disabled(session.isLoading) // Disable while request in progress.
                if let error = session.errorMessage, !error.isEmpty { // If an error message is present, show it inline.
                    Text(error) // Show readable error.
                        .foregroundColor(.red) // Red color to indicate error.
                        .font(.footnote) // Smaller font.
                        .multilineTextAlignment(.center) // Center align.
                }
                Spacer() // Push content upwards slightly.
            }
            .padding(20) // Outer padding to keep content away from edges.
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: session.errorMessage) { _, newValue in // Observe error changes.
            showErrorAlert = (newValue?.isEmpty == false) // Toggle alert when a new error appears.
        }
        .alert(String(localized: "auth.error.title"), isPresented: $showErrorAlert, actions: { // Present an alert for errors.
            Button(String(localized: "common.ok"), role: .cancel) { session.errorMessage = nil } // Dismiss action clears the error.
        }, message: { // Alert message content.
            Text(session.errorMessage ?? "") // Show the current error message.
        })
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

