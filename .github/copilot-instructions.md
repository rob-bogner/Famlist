✅ Do

Target & Architecture
    •    iOS 17+ only, SwiftUI only (no UIKit).
    •    MVVM pattern.
    •    Encapsulated & modular code; testable via protocols/DI.

File Header (every file)

/*
 FileName.swift

 GroceryGenius
 Created on: <original date>
 Last updated on: <today’s date>

 ------------------------------------------------------------------------
 📄 File Overview:
 - What this file does & why.

 🛠 Includes:
 - Key types, functions, purpose.

 🔰 Notes for Beginners:
 - Explain role in simple words.
 - Pitfalls/choices.

 📝 Last Change:
 - What & WHY it was changed.
 ------------------------------------------------------------------------
*/

Comments
    •    Every type/func/init gets a /// doc comment (purpose, params, return, notes).
    •    Every line has beginner-friendly comment (explain even trivial ones).
    •    SwiftUI previews must exist, commented line by line.

Project Structure
    •    Folders: Models/, Views/, ViewModels/, Repositories/, Services/, Support/.
    •    Descriptive names, no abbreviations.
    •    Reuse components, avoid duplication.

Separation of Concerns
    •    GroceryGeniusApp.swift: composition & DI only. ❗️No UI, toasts, or DB calls.
    •    Views: layout + user intents only.
    •    ViewModels: orchestrate use cases, call repos/services, manage state (@Published, @MainActor).
    •    Repos: DB access only, no UI.
    •    Services: cross-cutting concerns (e.g., Auth).

Error Handling
    •    Expose errors via ViewModel state (@Published var errorMessage).
    •    Show in Views (toast/alert).
    •    Clear, actionable messages.

Concurrency
    •    Use async/await only.
    •    UI updates on MainActor.
    •    Guard with isLoading; reset in defer.
    •    Cancel old tasks when inputs change.

Supabase & RLS
    •    Use anon key only (never Service Role key).
    •    Persist session, auto-refresh.
    •    Use explicit selects; .single() when 1 row expected.
    •    Don’t send owner_id if server sets it.
    •    Handle “not found” vs real errors distinctly.

Localization & Accessibility
    •    Use LocalizedStringKey, no hard-coded strings.
    •    Provide accessibilityLabel where relevant.

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
