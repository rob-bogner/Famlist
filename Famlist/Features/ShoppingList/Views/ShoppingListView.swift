/*
 ShoppingListView.swift

 GroceryGenius
 Created on: 27.11.2023
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Main shopping list screen combining decorative accent header, progress indicator, list content and quick-add control.

 🛠 Includes:
 - Accent header background + title + progress, list content, quick-add input, and modal for full add form.
 - Hamburger menu with profile view access and sign-out.

 🔰 Notes for Beginners:
 - Uses an EnvironmentObject (ListViewModel) so all subviews share the same data.
 - The quick-add expands inline; the full AddItemView is presented as a sheet for more details.

 📝 Last Change:
 - Added ProfileView integration via hamburger menu.
 ------------------------------------------------------------------------
 */

import SwiftUI // Imports SwiftUI for declarative UI building blocks and property wrappers.
import SwiftData // Provides ModelContext access for SwiftData-backed persistence.
import UIKit


/// The main screen showing the shopping list with a decorative header and actions.
struct ShoppingListView: View { // Declares a SwiftUI view type.
    @EnvironmentObject var listViewModel: ListViewModel // Shared data source and actions across the hierarchy.
    @EnvironmentObject var session: AppSessionViewModel // Session VM used to perform sign-out from the hamburger menu.
    @Environment(\.modelContext) private var modelContext // SwiftData context injected from GroceryGeniusApp.
    @Environment(\.scenePhase) private var scenePhase // Tracks foreground/background transitions for lifecycle-driven sync.
    @State private var addNewItem: Bool = false // Controls whether the AddItemView sheet is presented.
    @State private var quickAddActive: Bool = false // Tracks whether the inline quick-add text field is expanded.
    @State private var quickAddText: String = "" // Holds the text typed into the quick-add field.
    @FocusState private var quickAddFocused: Bool // Indicates whether the quick-add field currently has keyboard focus.
    @State private var didConfigurePersistence: Bool = false // Ensures we only configure SwiftData stores once per view lifecycle.

    private var contentOffsetBelowHeader: CGFloat { DS.Layout.headerFixedHeight + DS.Layout.headerBottomSpacing } // Push list completely below header with consistent spacing.

    var body: some View { // The view’s content and layout tree.
        NavigationView { // Embed in navigation for consistent behavior and potential future navigation.
            ZStack(alignment: .top) { // Stack layers starting from the top of the screen.
                Color.theme.background.ignoresSafeArea() // Fill the background with the app theme color, including safe areas.
                AccentHeaderBackground() // Decorative accent background with rounded bottom corners.
                    .frame(height: DS.Layout.headerFixedHeight) // Give the header a fixed height.
                    .zIndex(0) // Place behind other layers.
                VStack(alignment: .leading, spacing: 12) { // Header content: title and progress.
                    Text(String(localized: "shoppingList.title")) // Localized title text.
                        .font(.largeTitle.bold()) // Big, bold font for prominence.
                        .foregroundColor(Color.theme.background) // Contrast text against the accent background.
                        .padding(.top, 30) // Add space from the top edge.
                        .padding(.leading, 18) // Indent from the leading edge.
                    ShoppingListProgressView(listViewModel: listViewModel) // Small progress card showing checked vs total.
                        .padding(.top, 8) // Space below the title.
                    Spacer().frame(height: 4) // Tiny spacer to balance layout visually.
                }
 //               .frame(height: headerHeight, alignment: .top) // Constrain header content to the header area.
                .zIndex(1) // Float above the background.
                .overlay(alignment: .topTrailing) { // Overlay a hamburger menu at the top-right corner of the header.
                    hamburgerMenu // The menu with sign-out action.
                        .padding(.top, 30) // Align vertically with the title's top padding.
                        .padding(.trailing, 18) // Align horizontally with the header's trailing edge.
                }
                VStack(spacing: 0) { // Main content column with list and floating button.
                    Spacer().frame(height: contentOffsetBelowHeader) // Push list down so it starts under the header.
                    ZStack(alignment: .bottomTrailing) { // Layer the list and the floating add button.
                        ListView().environmentObject(listViewModel) // The list content reading from shared view model.
                        if quickAddActive { // If quick-add is expanded, show a tap-capturing overlay to dismiss it.
                            Color.black.opacity(0.001) // Invisible overlay to intercept taps.
                                .ignoresSafeArea() // Cover entire screen area.
                                .contentShape(Rectangle()) // Make the entire overlay tappable.
                                .onTapGesture { withAnimation { quickAddActive = false }; quickAddFocused = false } // Tap outside collapses quick-add and hides keyboard.
                        }
                        addButton // The floating button and inline field.
                            .padding(.bottom, 16) // Lift above bottom content.
                    }
                    Spacer() // Push content up slightly for breathing room.
                }
                .zIndex(2) // Place above header content.
            }
            .navigationBarHidden(true) // Use our custom header; hide default nav bar.
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .leading)), removal: .opacity.combined(with: .move(edge: .trailing)))) // Animated appear/disappear.
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Stack style for iPhone/iPad consistency.
        .sheet(isPresented: $addNewItem) { // Present full add form when requested.
            AddItemView() // The modal for adding a new item with more fields.
                .presentationDetents([.fraction(0.45), .large, .medium]) // Allow snap heights for the sheet.
                .presentationCornerRadius(15) // Rounded top corners for a modern look.
        }
        .onChange(of: scenePhase) { _, newPhase in // React to lifecycle changes so realtime sync stays reliable.
            switch newPhase { // Branch on scene state to decide which action to take.
            case .active: // When the app enters the foreground again.
                listViewModel.handleAppDidBecomeActive() // Resume observation when the app returns to the foreground.
            case .background: // When the app transitions to the background.
                listViewModel.handleAppDidEnterBackground() // Suspend observation when the app backgrounds.
            default:
                break // No action required for the inactive transition.
            }
        }
        .task { // Configure SwiftData-backed stores once the view appears.
            guard !didConfigurePersistence else { return }
            await MainActor.run {
                let itemStore = SwiftDataItemStore(context: modelContext)
                let listStore = SwiftDataListStore(context: modelContext)
                listViewModel.configure(localItemStore: itemStore, listStore: listStore)
                didConfigurePersistence = true
            }
        }
    }

    // MARK: - Hamburger Menu
    @State private var showProfileView: Bool = false // Controls ProfileView sheet presentation
    @State private var showImportView: Bool = false // Controls ClipboardImportView sheet presentation
    
    /// A top-left hamburger menu with session-related actions.
    private var hamburgerMenu: some View { // Computed view returning the menu for the header.
        Menu { // Menu content listing actions.
            Button {
                showProfileView = true // Show profile view sheet
            } label: {
                Label(String(localized: "menu.profile"), systemImage: "person.circle")
            }
            
            Button {
                showImportView = true // Show clipboard import view sheet
            } label: {
                Label(String(localized: "menu.import"), systemImage: "doc.on.clipboard")
            }
            
            Button(role: .destructive) { // Destructive styling to indicate a session-affecting action.
                session.signOut() // Trigger sign-out which removes the saved session and resets UI state.
            } label: { // Label for the sign-out action.
                Label(String(localized: "auth.signout.button"), systemImage: "rectangle.portrait.and.arrow.right") // Accessible label and icon.
            }
        } label: { // The tappable hamburger icon shown in the header.
            Image(systemName: "line.3.horizontal") // Standard hamburger icon.
                .font(.title2.weight(.bold)) // Visible size and weight.
                .foregroundColor(Color.theme.background) // Contrast icon against the accent header background.
                .accessibilityLabel(Text(String(localized: "menu.accessibility.hamburger"))) // VoiceOver label.
        }
        .buttonStyle(.plain) // Match add button styling to prevent iOS 26 from adding a bordered capsule look.
        .sheet(isPresented: $showProfileView) {
            if let profile = session.currentProfile {
                ProfileView(profile: profile)
                    .environmentObject(session)
            }
        }
        .sheet(isPresented: $showImportView) {
            ClipboardImportView()
                .environmentObject(listViewModel)
        }
    }

    // MARK: - Quick Add Button & Field
    /// Floating add button with an inline expanding text field for quick entry.
    private var addButton: some View { // Computed view for the quick-add control.
        ZStack(alignment: .trailing) { // Align text field and button at the trailing edge.
            TextField(String(localized: "quickadd.placeholder"), text: $quickAddText, onCommit: { addQuickItem() }) // Inline text input; pressing return adds the item.
                .padding(.horizontal, 14) // Add padding inside the text field.
                .frame(minWidth: 0, maxWidth: quickAddActive ? .infinity : 0, alignment: .trailing) // Expand to full width only when active.
                .frame(height: 52) // Fixed height for a comfortable touch target.
                .background(Color.theme.background) // Match the app background for a pill look.
                .overlay(Capsule().stroke(Color.theme.accent, lineWidth: 2)) // Accent outline around the pill field.
                .clipShape(Capsule()) // Round the field into a capsule.
                .focused($quickAddFocused) // Manage keyboard focus.
                .opacity(quickAddActive ? 1 : 0) // Only visible when active.
                .animation(.easeOut(duration: 0.2), value: quickAddActive) // Smoothly animate visibility changes.
            Button(action: buttonTap) { // Circular add/submit button.
                Image(systemName: quickAddActive ? "paperplane.fill" : "plus") // Swap icon when field is active.
                    .rotationEffect(quickAddActive ? .degrees(45) : .degrees(0)) // Small rotation for fun when active.
                    .animation(.easeInOut(duration: 0.28), value: quickAddActive) // Animate the rotation.
                    .font(.system(size: 22, weight: .bold)) // Bold, visible icon size.
                    .frame(width: quickAddActive ? 38 : 48, height: quickAddActive ? 38 : 48) // Shrink slightly when active.
                    .animation(.easeInOut(duration: 0.26), value: quickAddActive) // Animate size changes.
                    .foregroundColor(.white) // White icon on accent background.
                    .background(Circle().fill(Color.theme.accent)) // Circular accent background.
                    .overlay(Circle().stroke(Color.theme.accent, lineWidth: 2)) // Subtle outline for definition.
                    .offset(x: quickAddActive ? -8 : 0) // Nudge left when the field is visible.
                    .animation(.easeInOut(duration: 0.24), value: quickAddActive) // Animate the nudge.
            }
            .buttonStyle(.plain) // Remove iOS default button styling to prevent gray border on iOS 26 devices.
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.7).onEnded { _ in // Long-press opens the full add form.
                quickAddActive = false // Collapse inline field if open.
                quickAddText = "" // Clear any partial input.
                addNewItem = true // Show the AddItemView sheet.
            })
        }
        .padding(.horizontal, 16) // Keep away from screen edges.
        .padding(.bottom, 16) // Lift above bottom edge for reachability.
        .frame(height: DS.Layout.quickAddHeight, alignment: .trailing) // Match design system height and align trailing.
    }

    /// Handles taps on the floating add button to either submit or expand.
    private func buttonTap() { // Simple action handler.
        if quickAddActive { addQuickItem() } else { // If field is open, treat as submit; else open field.
            quickAddFocused = true // Focus the text field to bring up keyboard.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { withAnimation { quickAddActive = true } } // Slight delay for polished animation.
        }
    }

    /// Validates and adds a quick item from the inline field.
    private func addQuickItem() { // Trims, validates, and delegates to view model.
        let trimmed = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines) // Remove extra spaces/newlines.
        guard !trimmed.isEmpty else { return } // Ignore empty input.
        listViewModel.addQuickItem(trimmed) // Ask the view model to create a basic item.
        quickAddText = "" // Clear field after submit.
        withAnimation { quickAddActive = false } // Collapse the field.
        quickAddFocused = false // Dismiss the keyboard.
    }
}

#Preview { // SwiftUI live preview for this view.
    // Build preview dependencies and inject both list and session view models.
    let listVM = PreviewMocks.makeListViewModelWithSamples() // In-memory list VM with sample items.
    let sessionVM = AppSessionViewModel(client: nil, // No real client in previews.
                                        profiles: PreviewProfilesRepository(), // Preview profiles repo.
                                        lists: PreviewListsRepository(), // Preview lists repo.
                                        listViewModel: listVM) // Inject list VM.
    return ShoppingListView() // Render the list view.
        .modelContainer(PersistenceController.preview.container) // Provide in-memory SwiftData container for previews.
        .environmentObject(listVM) // Provide list view model to the environment.
        .environmentObject(sessionVM) // Provide session view model for the hamburger menu.
}
