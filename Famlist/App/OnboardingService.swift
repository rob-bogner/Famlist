/*
 OnboardingService.swift

 Famlist
 Created on: 18.10.2025
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Service handling new user onboarding (profile creation, public ID generation).

 🛠 Includes:
 - createProfileForNewUser (creates profile with generated public_id)
 - generatePublicId (8-character alphanumeric ID for sharing)

 🔰 Notes for Beginners:
 - Extracted from AppSessionViewModel to follow Single Responsibility principle.
 - Handles first-time user setup automatically after authentication.
 - The service is stateless; state management remains in AppSessionViewModel.

 📝 Last Change:
 - Extracted from AppSessionViewModel.swift to reduce file size and improve testability.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides UUID and String operations.

/// Service handling new user onboarding operations.
@MainActor
final class OnboardingService {
    
    // MARK: - Dependencies
    
    private let client: SupabaseClienting
    private let profiles: ProfilesRepository
    
    // MARK: - Lifecycle
    
    /// Creates an OnboardingService with the given dependencies.
    /// - Parameters:
    ///   - client: Supabase client facade for auth operations.
    ///   - profiles: Profiles repository for creating user profiles.
    init(client: SupabaseClienting, profiles: ProfilesRepository) {
        self.client = client
        self.profiles = profiles
    }
    
    // MARK: - Profile Creation
    
    /// Creates a profile for a new user who doesn't have one yet (first-time magic link sign-up).
    /// - Returns: The newly created Profile with generated public_id.
    /// - Throws: Error if profile creation fails.
    func createProfileForNewUser() async throws -> Profile {
        // Get the authenticated user ID from the current session
        let userId: UUID
        if let currentId = client.auth.currentUser?.id {
            userId = currentId
        } else {
            let session = try await client.auth.session
            userId = session.user.id
        }
        
        // Generate a unique public_id for sharing lists (8-character alphanumeric)
        let publicId = generatePublicId()
        
        // Create the profile using the repository
        try await profiles.upsertProfile(authUserId: userId, publicId: publicId)
        
        // Fetch and return the newly created profile
        let newProfile = try await profiles.myProfile()
        return newProfile
    }
    
    // MARK: - Helper Methods
    
    /// Generates a random 8-character alphanumeric string for public_id.
    /// - Returns: A string like "A3K9M2X7" for sharing purposes.
    private func generatePublicId() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).map { _ in characters.randomElement()! })
    }
}

