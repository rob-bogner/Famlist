/*
 ShoppingListView.swift

 Famlist
 Created on: 27.11.2023
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Main shopping list screen combining decorative accent header, progress indicator and list content.

 🛠 Includes:
 - Accent header background + title + progress, list content, AddItemView sheet.
 - FloatingBottomMenuBar mit Toggle-All, Sort, Add, Import und Hamburger-Menu.

 🔰 Notes for Beginners:
 - Uses an EnvironmentObject (ListViewModel) so all subviews share the same data.
 - FloatingBottomMenuBar liegt als eigene Komponente in Shared/Components.

 📝 Last Change:
 - Quick-Add-Inline-Feld entfernt, FloatingBottomMenuBar (dunkles Pill-Design) integriert.
 ------------------------------------------------------------------------
 */

import SwiftUI // Imports SwiftUI for declarative UI building blocks and property wrappers.
import SwiftData // Provides ModelContext access for SwiftData-backed persistence.


/// The main screen showing the shopping list with a decorative header and actions.
struct ShoppingListView: View { // Declares a SwiftUI view type.
    @EnvironmentObject var listViewModel: ListViewModel // Shared data source and actions across the hierarchy.
    @EnvironmentObject var session: AppSessionViewModel // Session VM used to perform sign-out from the hamburger menu.
    @Environment(\.modelContext) private var modelContext // SwiftData context injected from FamlistApp.
    @Environment(\.scenePhase) private var scenePhase // Tracks foreground/background transitions for lifecycle-driven sync.
    @State private var addNewItem: Bool = false // Controls whether the AddItemView sheet is presented.
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
                        .foregroundColor(Color.theme.universalWhite) // Kontrastreicher Titeltext auf Accent-Header.
                        .padding(.top, 30) // Add space from the top edge.
                        .padding(.leading, 18) // Indent from the leading edge.
                    
                    ShoppingListProgressView(listViewModel: listViewModel) // Small progress card showing checked vs total.
                        .padding(.top, 8) // Space below the title.
                    Spacer().frame(height: 4) // Tiny spacer to balance layout visually.
                }
 //               .frame(height: headerHeight, alignment: .top) // Constrain header content to the header area.
                .zIndex(1) // Float above the background.
                VStack(spacing: 0) { // Main content column with list.
                    Spacer().frame(height: contentOffsetBelowHeader) // Push list down so it starts under the header.
                    ListView()
                        .environmentObject(listViewModel) // The list content reading from shared view model.
                        .safeAreaInset(edge: .bottom) {
                            Spacer().frame(height: 90) // Freiraum damit Items nicht hinter der Menüleiste verschwinden.
                        }
                    Spacer() // Push content up slightly for breathing room.
                }
                .zIndex(2) // Place above header content.

                // Schwebende Menüleiste am unteren Bildschirmrand.
                VStack {
                    Spacer()
                    FloatingBottomMenuBar(onAddTap: { addNewItem = true })
                        .environmentObject(listViewModel)
                        .environmentObject(session)
                }
                .zIndex(3) // Über allen anderen Ebenen.
                
            }
            .navigationBarHidden(true) // Use our custom header; hide default nav bar.
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .leading)), removal: .opacity.combined(with: .move(edge: .trailing)))) // Animated appear/disappear.
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Stack style for iPhone/iPad consistency.
        .sheet(isPresented: $addNewItem) { // Present search sheet or direct add form.
            if let catalogRepo = listViewModel.catalogRepository {
                // Smart search: user can find existing catalog items or create new ones.
                ItemSearchView(catalogRepository: catalogRepo)
            } else {
                // Fallback: direct add form (preview mode / no catalog configured).
                AddItemView()
                    .presentationDetents([.fraction(0.45), .large, .medium])
                    .presentationCornerRadius(15)
                    .presentationDragIndicator(.visible)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
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
