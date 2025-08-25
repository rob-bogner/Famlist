// MARK: - ShoppingListView.swift

/*
 File: ShoppingListView.swift
 Project: GroceryGenius
 Created: 27.11.2023
 Last Updated: 17.08.2025

 Overview:
 Main shopping list screen combining decorative accent header, progress indicator, list content and quick-add control.

 Responsibilities / Includes:
 - Accent header background + title + progress
 - List of unchecked + checked items (delegated to ListView)
 - Quick-add inline input with animated expansion & FAB behaviour
 - Modal sheet for full add-item form (AddItemView)

 Design Notes:
 - Header height derived from design token ratio for responsiveness
 - Quick-add keeps TextField in hierarchy for smoother animation (width/opacity transitions)
 - Light tap overlay dismisses quick-add when active
 - EnvironmentObject supplies reactive ListViewModel state

 Possible Enhancements:
 - Migrate to NavigationStack
 - Add pull-to-refresh / offline badge
 - Extract quick-add control into its own component
*/

import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject var listViewModel: ListViewModel
    @State private var addNewItem: Bool = false
    @State private var quickAddActive: Bool = false
    @State private var quickAddText: String = ""
    @FocusState private var quickAddFocused: Bool

    private var headerHeight: CGFloat { UIScreen.main.bounds.height * DS.Layout.headerHeightRatio }
    private var contentOffsetBelowHeader: CGFloat { headerHeight * 0.75 }

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                Color.theme.background.ignoresSafeArea()
                AccentHeaderBackground()
                    .frame(height: headerHeight)
                    .zIndex(0)
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "shoppingList.title"))
                        .font(.largeTitle.bold())
                        .foregroundColor(Color.theme.background)
                        .padding(.top, 30)
                        .padding(.leading, 18)
                    ShoppingListProgressView(listViewModel: listViewModel)
                        .padding(.top, 8)
                    Spacer().frame(height: 4)
                }
                .frame(height: headerHeight, alignment: .top)
                .zIndex(1)
                VStack(spacing: 0) {
                    Spacer().frame(height: contentOffsetBelowHeader)
                    ZStack(alignment: .bottomTrailing) {
                        ListView().environmentObject(listViewModel)
                        if quickAddActive {
                            Color.black.opacity(0.001)
                                .ignoresSafeArea()
                                .contentShape(Rectangle())
                                .onTapGesture { withAnimation { quickAddActive = false }; quickAddFocused = false }
                        }
                        addButton
                            .padding(.bottom, 16)
                    }
                    Spacer()
                }
                .zIndex(2)
            }
            .toolbar(.hidden, for: .navigationBar)
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .leading)), removal: .opacity.combined(with: .move(edge: .trailing))))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $addNewItem) {
            AddItemView()
                .presentationDetents([.fraction(0.45), .large, .medium])
                .presentationCornerRadius(15)
        }
    }

    // MARK: - Quick Add Button & Field
    private var addButton: some View {
        ZStack(alignment: .trailing) {
            TextField(String(localized: "quickadd.placeholder"), text: $quickAddText, onCommit: { addQuickItem() })
                .padding(.horizontal, 14)
                .frame(minWidth: 0, maxWidth: quickAddActive ? .infinity : 0, alignment: .trailing)
                .frame(height: 52)
                .background(Color.theme.background)
                .overlay(Capsule().stroke(Color.theme.accent, lineWidth: 2))
                .clipShape(Capsule())
                .focused($quickAddFocused)
                .opacity(quickAddActive ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: quickAddActive)
            Button(action: buttonTap) {
                Image(systemName: quickAddActive ? "paperplane.fill" : "plus")
                    .rotationEffect(quickAddActive ? .degrees(45) : .degrees(0))
                    .animation(.easeInOut(duration: 0.28), value: quickAddActive)
                    .font(.system(size: 22, weight: .bold))
                    .frame(width: quickAddActive ? 38 : 48, height: quickAddActive ? 38 : 48)
                    .animation(.easeInOut(duration: 0.26), value: quickAddActive)
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.theme.accent))
                    .overlay(Circle().stroke(Color.theme.accent, lineWidth: 2))
                    .offset(x: quickAddActive ? -8 : 0)
                    .animation(.easeInOut(duration: 0.24), value: quickAddActive)
            }
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.7).onEnded { _ in
                quickAddActive = false
                quickAddText = ""
                addNewItem = true
            })
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(height: DS.Layout.quickAddHeight, alignment: .trailing)
    }

    private func buttonTap() {
        if quickAddActive { addQuickItem() } else {
            quickAddFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { withAnimation { quickAddActive = true } }
        }
    }

    private func addQuickItem() {
        let trimmed = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        listViewModel.addQuickItem(trimmed)
        quickAddText = ""
        withAnimation { quickAddActive = false }
        quickAddFocused = false
    }
}

#Preview { ShoppingListView().environmentObject(ListViewModel(repository: PreviewItemsRepository())) }
