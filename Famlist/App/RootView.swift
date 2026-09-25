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
    /// Einstellungen → Erscheinungsbild (System / Hell / Dunkel), gilt app-weit.
    @AppStorage(ListAccountAppearanceChoice.storageKey) private var appearanceRaw = ListAccountAppearanceChoice.system.rawValue

    var body: some View { // Root view body.
        Group { // Conditional container to switch views without rebuilding hierarchy unnecessarily.
            if session.isRestoringSession { // If session is restoring, show a loading indicator.
                SplashView() // Splash im Hybrid-Design: gleiches Logo wie der Launch Screen + Spinner.
                    .accessibilityLabel(Text(String(localized: "auth.session.restoring"))) // Accessibility label for loading.
                    .transition(.opacity)
            } else if session.isAuthenticated { // If authenticated and not restoring, show the main app UI.
                if session.needsProfileSetup {
                    ProfileSetupView() // Schritt 2 von 2: Benutzername fehlt noch.
                } else if let invite = session.pendingInvite {
                    AcceptInviteView(invite: invite) // Einladungslink: annehmen oder ablehnen.
                } else {
                    ShoppingListView() // Main list UI.
                        .environmentObject(listViewModel) // Ensure list VM is available to descendants.
                }
            } else { // Not authenticated and not restoring -> present sign-in form.
                SignInView() // E-Mail-Anmeldelink oder „Mit Apple anmelden“.
            }
        }
        .preferredColorScheme(ListAccountAppearanceChoice(rawValue: appearanceRaw)?.colorScheme)
        .animation(.easeInOut(duration: 0.3), value: session.isRestoringSession)
        .animation(.easeInOut(duration: 0.3), value: session.needsProfileSetup)
        .animation(.easeInOut(duration: 0.3), value: session.pendingInvite?.listId)
        .onOpenURL { url in // Handle deep links such as the Supabase magic-link callback.
            session.handleOpenURL(url) // Forward URL to session VM to extract session via Supabase.
        }
    }
}

// MARK: - Splash (Design: Splash.dc.html / SplashDark.dc.html)

/// Splash im Redesign „Hybrid“. Nahtloser Übergang vom Launch Screen:
/// Hintergrund (`LaunchBackground`) und Logo-Gruppe (`LaunchLogo`, 320 × 286 pt inkl. 40 pt Rand)
/// sind dieselben Assets wie im Launch Screen (Info.plist → UILaunchScreen), exakt mittig.
/// Neu kommt nur der Spinner dazu: 32 × 32, Unterkante 120 pt über dem Bildschirmrand.
struct SplashView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        ZStack {
            Color("LaunchBackground")
            if dark {
                // radial-gradient(120% 60% at 50% 100%, rgba(accent, .1), transparent 60%)
                GeometryReader { geo in
                    EllipticalGradient(colors: [Color.rgba(31, 194, 204, 0.1), .clear],
                                       center: .bottom, startRadiusFraction: 0, endRadiusFraction: 0.6)
                        .frame(width: geo.size.width * 2.4, height: geo.size.height * 1.2)
                        .position(x: geo.size.width / 2, y: geo.size.height)
                }
            }
            Image("LaunchLogo")
            VStack {
                Spacer()
                SplashSpinner(dark: dark)
                    .padding(.bottom, 120)
            }
        }
        .ignoresSafeArea()
    }
}

/// Spinner 32 × 32: Ring (Strich 3,5) + Viertelbogen mit runder Kappe, 1 Umdrehung pro Sekunde.
struct SplashSpinner: View {
    let dark: Bool
    @State private var spinning = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(dark ? Color.rgba(31, 194, 204, 0.18) : Color.rgba(15, 163, 174, 0.14), lineWidth: 3.5)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(dark ? Color.hex("#67D6DC") : Color.hex("#0FA3AE"),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 26, height: 26)                      // r 13 (Strich mittig auf dem Kreis wie im SVG)
        .frame(width: 32, height: 32)
        .rotationEffect(.degrees(spinning ? 360 : 0))
        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: spinning)
        .onAppear { spinning = true }
        .accessibilityHidden(true)
    }
}

#Preview("Splash") { SplashView() }
#Preview("Splash – Dark") { SplashView().preferredColorScheme(.dark) }

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
        .environmentObject(CategoryStore(repository: nil))
        .environmentObject(PriceBook(repository: nil))
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
        .environmentObject(CategoryStore(repository: nil))
        .environmentObject(PriceBook(repository: nil))
}
