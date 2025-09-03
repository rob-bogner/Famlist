/*
 ShoppingListView.swift

 GroceryGenius
 Created on: 27.11.2023
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Main shopping list screen combining decorative accent header, progress indicator, list content and quick-add control.

 🛠 Includes:
 - Accent header background + title + progress, list content, quick-add input, and modal for full add form.

 🔰 Notes for Beginners:
 - Uses an EnvironmentObject (ListViewModel) so all subviews share the same data.
 - The quick-add expands inline; the full AddItemView is presented as a sheet for more details.

 📝 Last Change:
 - Standardized header and preview uses PreviewMocks for consistent demo data. No functional changes.
 ------------------------------------------------------------------------
 */

import SwiftUI // Imports SwiftUI for declarative UI building blocks and property wrappers.


/// The main screen showing the shopping list with a decorative header and actions.
struct ShoppingListView: View { // Declares a SwiftUI view type.
    @EnvironmentObject var listViewModel: ListViewModel // Shared data source and actions across the hierarchy.
    @State private var addNewItem: Bool = false // Controls whether the AddItemView sheet is presented.
    @State private var quickAddActive: Bool = false // Tracks whether the inline quick-add text field is expanded.
    @State private var quickAddText: String = "" // Holds the text typed into the quick-add field.
    @FocusState private var quickAddFocused: Bool // Indicates whether the quick-add field currently has keyboard focus.

    private var headerHeight: CGFloat { UIScreen.main.bounds.height * DS.Layout.headerHeightRatio } // Computes header height based on the screen height.
    private var contentOffsetBelowHeader: CGFloat { headerHeight * 0.75 } // Offset so content begins overlapping under the header.

    var body: some View { // The view’s content and layout tree.
        NavigationView { // Embed in navigation for consistent behavior and potential future navigation.
            ZStack(alignment: .top) { // Stack layers starting from the top of the screen.
                Color.theme.background.ignoresSafeArea() // Fill the background with the app theme color, including safe areas.
                AccentHeaderBackground() // Decorative accent background with rounded bottom corners.
                    .frame(height: headerHeight) // Give the header a fixed height.
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
                .frame(height: headerHeight, alignment: .top) // Constrain header content to the header area.
                .zIndex(1) // Float above the background.
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
    ShoppingListView().environmentObject(PreviewMocks.makeListViewModelWithSamples()) // Inject a preview model to render content.
}
