/*
 RootView.swift

 Famlist
 Created on: 07.09.2025
 Last updated on: 07.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Root SwiftUI view that toggles between AuthView and the main ShoppingListView based on authentication state.

 🛠 Includes:
 - Deep link handling for Supabase magic-link login and session restore on launch.

 🔰 Notes for Beginners:
 - This view holds no business logic; it delegates to AppSessionViewModel for auth and bootstrapping.
 - The deep-link handler forwards the URL to the session view model, which extracts the session from Supabase.

 📝 Last Change:
 - Initial creation to wire the new authentication flow per spec.
 ------------------------------------------------------------------------
 */

import SwiftUI // Import SwiftUI to define views.

/// Top-level container that decides whether to show AuthView or ShoppingListView.
struct RootView: View { // SwiftUI View declaration.
    @EnvironmentObject var session: AppSessionViewModel // Session VM controlling auth status.
    @EnvironmentObject var listViewModel: ListViewModel // List VM used by ShoppingListView subtree.

    var body: some View { // Root view body.
        Group { // Conditional container to switch views without rebuilding hierarchy unnecessarily.
            if session.isRestoringSession { // If session is restoring, show a loading indicator.
                ProgressView() // Show a spinner while restoring session.
                    .accessibilityLabel(Text(String(localized: "auth.session.restoring"))) // Accessibility label for loading.
            } else if session.isAuthenticated { // If authenticated and not restoring, show the main app UI.
                ShoppingListView() // Main list UI.
                    .environmentObject(listViewModel) // Ensure list VM is available to descendants.
            } else { // Not authenticated and not restoring -> present sign-in form.
                AuthView() // Email magic-link sign-in screen.
            }
        }
        .onOpenURL { url in // Handle deep links such as the Supabase magic-link callback.
            session.handleOpenURL(url) // Forward URL to session VM to extract session via Supabase.
        }
    }
}

#Preview {
    // Preview the unauthenticated state.
    let listVM = PreviewMocks.makeListViewModelWithSamples() // Create a preview list VM with sample data.
    let sessionVM = AppSessionViewModel(client: nil, // No real client in previews.
                                        profiles: PreviewProfilesRepository(), // Preview profile repo.
                                        lists: PreviewListsRepository(), // Preview lists repo.
                                        listViewModel: listVM) // Inject list VM.
    return RootView() // Render RootView for preview.
        .environmentObject(sessionVM) // Inject session VM.
        .environmentObject(listVM) // Inject list VM.
}

#Preview("Authenticated") {
    // Preview the authenticated state by toggling the flag.
    let listVM = PreviewMocks.makeListViewModelWithSamples() // Preview list VM with items.
    let sessionVM = AppSessionViewModel(client: nil, // No client for previews.
                                        profiles: PreviewProfilesRepository(), // Preview profiles repo.
                                        lists: PreviewListsRepository(), // Preview lists repo.
                                        listViewModel: listVM) // Inject list VM.
    sessionVM.isAuthenticated = true // Simulate authenticated state.
    return RootView() // Render RootView for preview.
        .environmentObject(sessionVM) // Inject session VM.
        .environmentObject(listVM) // Inject list VM.
}
