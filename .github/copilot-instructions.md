# GroceryGenius AI Development Guide

## Architecture Overview
- **iOS 17+ SwiftUI-only** grocery list app with Supabase backend
- **Strict MVVM**: Views → ViewModels → Repositories → Supabase
- **Repository pattern** with protocol abstraction enables preview/test mocking
- **Dependency injection** from `GroceryGeniusApp.swift` (composition root)

## Critical Patterns

### File Headers (Required)
Every file must have this exact header format:
```swift
/*
 FileName.swift
 GroceryGenius
 Created on: <original date>
 Last updated on: <today's date>

 ------------------------------------------------------------------------
 📄 File Overview: What this file does & why
 🛠 Includes: Key types, functions, purpose  
 🔰 Notes for Beginners: Role explanation & pitfalls
 📝 Last Change: What & WHY it was changed
 ------------------------------------------------------------------------
*/
```

### Supabase Configuration
- **Never commit `Secrets.plist`** - use `Secrets.example.plist` as template
- When `Secrets.plist` missing → app uses `PreviewItemsRepository` (in-memory)
- **RLS enforced**: Use anon key only, server sets `owner_id` automatically
- **Error handling**: Distinguish "not found" from network/auth errors

### Repository Pattern
```swift
protocol ItemsRepository {
    func observeItems(listId: UUID) -> AsyncStream<[ItemModel]>
    func createItem(_ item: ItemModel) async throws -> ItemModel
}
```
- `SupabaseItemsRepository` → real backend
- `PreviewItemsRepository` → in-memory for previews/tests
- Inject via `GroceryGeniusApp.swift` constructor

### ViewModels Must Be @MainActor
```swift
@MainActor
class ListViewModel: ObservableObject {
    @Published var items: [ItemModel] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
}
```
- All UI state updates on main thread
- Guard operations with `isLoading`, reset in `defer`
- Expose errors via `@Published var errorMessage`

### Strict Separation of Concerns
- **`GroceryGeniusApp.swift`**: DI composition ONLY - no UI/DB/business logic
- **Views**: Layout + user intents → delegate to ViewModels
- **ViewModels**: Orchestrate use cases, manage `@Published` state
- **Repositories**: Pure data access, return Swift models
- **`RootView.swift`**: Auth flow coordinator (AuthView ↔ ShoppingListView)

## Essential Workflows

### Development Setup
1. Copy `Secrets.example.plist` → `Secrets.plist`
2. Add your Supabase URL + anon key
3. **Without secrets**: App runs with in-memory data

### Design System Usage
Use `DS` tokens instead of magic numbers:
```swift
.padding(DS.Spacing.medium) // Not .padding(16)
.cornerRadius(DS.CornerRadius.medium) // Not .cornerRadius(8)
```

### Preview Pattern
Always provide SwiftUI previews using `PreviewMocks`:
```swift
#Preview {
    ListView()
        .environmentObject(PreviewMocks.makeListViewModelWithSamples())
}
```

### Async/Await Patterns
```swift
private func loadItems() {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    
    do {
        items = try await repository.fetchItems(listId: listId)
    } catch {
        errorMessage = "Failed to load items: \(error.localizedDescription)"
    }
}
```

### Comments Requirements
- **Every type/function**: `///` documentation
- **Every line**: Beginner-friendly inline comments
- **SwiftUI previews**: Comment each line explaining purpose

## Project Structure
- **Folders**: `Models/`, `Views/`, `ViewModels/`, `Service/`, `Components/`, `Support/`
- **Descriptive names**, no abbreviations
- **Reuse components**, avoid duplication

## Key Files to Understand
- `GroceryGeniusApp.swift`: DI composition root
- `RootView.swift`: Auth flow coordinator
- `ListViewModel.swift`: Primary business logic orchestrator
- `SupabaseRepositories.swift`: Backend data access implementations
- `PreviewMocks.swift`: Preview data factory
- `DesignSystem.swift`: UI tokens (`DS.Spacing.*`, `DS.CornerRadius.*`)

## Error Handling
- Expose errors via ViewModel state (`@Published var errorMessage`)
- Show in Views (toast/alert)
- Clear, actionable messages

## Concurrency
- Use `async/await` only
- UI updates on `MainActor`
- Guard with `isLoading`; reset in `defer`
- Cancel old tasks when inputs change

## Supabase & RLS
- Use anon key only (never Service Role key)
- Persist session, auto-refresh
- Use explicit selects; `.single()` when 1 row expected
- Don't send `owner_id` if server sets it
- Handle "not found" vs real errors distinctly

## Git Workflow
**Rules**: No commits/pushes unless explicitly requested

**Commit format**: `[PREFIX](optional-scope): short present-tense message`

**Prefixes**:
- `FEAT` / `ENHANCE` = features
- `REFACTOR` / `STYLE` / `PERF` = code quality
- `FIX` / `HOTFIX` = bug fixes
- `DOCS`, `TEST`, `BUILD`, `CI`, `CHORE` = as named

**Example**:
```
STYLE(ProductImageFullscreenView): Align modal header with EditItemView

- Match title & xmark styling
- Use identical padding & accent color
#UI #consistency
```

## ❌ Don't
- Don't use UIKit
- Don't skip comments
- Don't break MVVM
- Don't put logic in `App.swift`
- Don't DB-call in Views/App
- Don't swallow errors
- Don't block threads
- Don't use unclear commit messages

⸻

📝 Git Workflow

Rules
    •    No commits/pushes unless I explicitly request.
    •    Commit format:
[PREFIX](optional-scope): short present-tense message

Prefixes
    •    FEAT / ENHANCE = features.
    •    REFACTOR / STYLE / PERF = code quality.
    •    FIX / HOTFIX = bug fixes.
    •    DOCS, TEST, BUILD, CI, CHORE = as named.

Example

STYLE(ProductImageFullscreenView): Align modal header with EditItemView

- Match title & xmark styling
- Use identical padding & accent color
#UI #consistency

Checklist
    •    Correct prefix?
    •    Optional scope?
    •    Short, imperative title.
    •    Add description/footers only if needed.

⸻

❌ Don’t
    •    Don’t use UIKit.
    •    Don’t skip comments.
    •    Don’t break MVVM.
    •    Don’t put logic in App.swift.
    •    Don’t DB-call in Views/App.
    •    Don’t swallow errors.
    •    Don’t block threads.
    •    Don’t use unclear commit messages.
