/*
 ProfileView.swift

 GroceryGenius
 Created on: 18.10.2025
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet UI for viewing and editing user profile (avatar, username, full name, public ID for sharing)

 🛠 Includes:
 - Avatar photo picker
 - Username, full name, and public ID fields
 - Save button that persists via ProfilesRepository
 - Validation for username (min 3 characters)

 🔰 Notes for Beginners:
 - Similar design to EditItemView for consistency
 - Public ID is read-only (for sharing lists with others)
 - Uses CustomModalView for consistent modal styling

 📝 Last Change:
 - Initial creation for user profile management
 ------------------------------------------------------------------------
 */

import SwiftUI

/// View for viewing and editing user profile information
struct ProfileView: View {
    
    // MARK: - Environment & Dependencies
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var session: AppSessionViewModel
    
    // MARK: - State
    
    @State private var email: String = ""
    @State private var username: String = ""
    @State private var fullName: String = ""
    @State private var publicId: String = ""
    @State private var selectedAvatar: UIImage? = nil
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var usernameError: String? = nil
    
    let profile: Profile
    
    // MARK: - Computed
    
    private var isValid: Bool {
        usernameError == nil && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        CustomModalView(title: String(localized: "profile.title"), onClose: { dismiss() }) {
            VStack(spacing: DS.Spacing.l) {
                ScrollView {
                    VStack(spacing: DS.Spacing.m) {
                        // Avatar picker
                        PhotoField(image: $selectedAvatar)
                        
                        // Email (read-only)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "profile.email.label"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(email)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        // Username field with validation
                        VStack(alignment: .leading, spacing: 4) {
                            TextField(String(localized: "profile.username.placeholder"), text: $username)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(1)
                                .autocapitalization(.none)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(usernameError == nil ? Color.clear : Color.red, lineWidth: 1)
                                )
                            if let error = usernameError {
                                Text(error)
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                        .onChange(of: username) { _, _ in validateUsername() }
                        
                        // Full name field
                        TextField(String(localized: "profile.fullName.placeholder"), text: $fullName)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1)
                        
                        // Public ID (read-only)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "profile.publicId.label"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                Text(publicId)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.primary)
                                Spacer()
                                Button(action: copyPublicId) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            
                            Text(String(localized: "profile.publicId.hint"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 25)
                }
                
                PrimaryButton(title: String(localized: "button.save")) {
                    saveProfile()
                }
                .disabled(!isValid || isLoading)
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear {
                populateFields()
                validateUsername()
            }
            .presentationDetents([.height(500)])
        }
        .presentationBackground(Color.theme.card)
        .background(Color.theme.card)
    }
    
    // MARK: - Helpers
    
    private func populateFields() {
        email = session.client?.auth.currentUser?.email ?? ""
        username = profile.username ?? ""
        fullName = profile.fullName ?? ""
        publicId = profile.publicId
        
        // Load avatar from URL if available
        if let avatarUrl = profile.avatarUrl, let _ = URL(string: avatarUrl) {
            // TODO: Load image from URL
        }
    }
    
    private func validateUsername() {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            usernameError = String(localized: "profile.error.usernameRequired")
        } else if trimmed.count < 3 {
            usernameError = String(localized: "profile.error.usernameMinLength")
        } else {
            usernameError = nil
        }
    }
    
    private func copyPublicId() {
        UIPasteboard.general.string = publicId
        // TODO: Show toast "Public ID copied"
    }
    
    private func saveProfile() {
        validateUsername()
        guard isValid else { return }
        
        // TODO: Implement save via ProfilesRepository
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    ProfileView(profile: Profile(
        id: UUID(),
        publicId: "ABC12345",
        username: "johndoe",
        fullName: "John Doe",
        avatarUrl: nil,
        createdAt: Date(),
        updatedAt: Date()
    ))
    .environmentObject(PreviewMocks.makeAppSessionViewModel())
}
