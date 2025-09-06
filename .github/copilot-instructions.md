✅ Do

Target & Architecture
    •    Always target iOS 17+
    •    Use SwiftUI only (no UIKit)
    •    Follow MVVM pattern
    •    Keep code encapsulated, modular, and testable via protocols/DI

File Header (every file)

/*
 FileName.swift

 GroceryGenius
 Created on: <original date>
 Last updated on: <today’s date>

 ------------------------------------------------------------------------
 📄 File Overview:
 - Short description of what this file does and why it exists.

 🛠 Includes:
 - Key types, functions, and their purpose.

 🔰 Notes for Beginners:
 - Explain the role of this file in simple words.
 - Mention pitfalls or reasons behind implementation choices.

 📝 Last Change:
 - What was changed and WHY it was changed.
 ------------------------------------------------------------------------
*/

Comments
    •    Every function/initializer/struct/enum/class gets a doc comment (///) explaining purpose, parameters, return value, special considerations.
    •    Every single line of code has a beginner-friendly comment (/// above or // at end of line).
    •    Explain even trivial lines (import SwiftUI, {}, .padding()).
    •    Example: .padding(.horizontal) // adds horizontal space (left + right) around this view
    •    All SwiftUI previews must exist and be commented line by line.

Project Structure
    •    Folders: Models/, Views/, ViewModels/, Repositories/, Services/, Support/ (e.g., UI/DesignSystem, Utilities)
    •    Use descriptive names, no abbreviations.
    •    Promote reusability, avoid duplication.
    •    Follow Swift & SwiftUI best practices.

Separation of Concerns (strict)
    •    GroceryGeniusApp.swift: Only composition & dependency injection (create clients, repositories, view models, scene).
    •    ❗️No UI logic, no business logic, no toasts, no network calls with business rules here.
    •    If needed, kick off work via .task on a root View or expose a method on a ViewModel.
    •    Views: UI only (layout, rendering, user intents). No direct DB calls. Bind to a ViewModel.
    •    ViewModels: Orchestrate use cases, call repositories/services, manage state.
    •    Update @Published on MainActor.
    •    Use isLoading with defer to reset.
    •    Cancel previous tasks on input changes (e.g., list switch).
    •    Repositories: Data access only (Supabase I/O). No UI, no toasts. Return domain models or DTOs.
    •    Services (e.g., AuthService): Cross-cutting concerns like Auth session restore, auth state stream.

Error Handling & UX
    •    Surface errors via ViewModel state (e.g., @Published var errorMessage: String?) and show them in Views (Toast/Alert).
    •    Do not present toasts from App or Repositories.
    •    Use clear, actionable messages (e.g., “Not signed in. Please sign in to load your list.”).
    •    Prefer typed errors where practical; never silently swallow errors.

Concurrency & Performance
    •    Use async/await; avoid DispatchSemaphore or sync bridges.
    •    UI state updates on MainActor (@MainActor or await MainActor.run).
    •    Guard against concurrent loads (if isLoading { return }) and always defer { isLoading = false }.
    •    Avoid heavy work in Views; move to ViewModel/Service.

Supabase & RLS (security-first)
    •    Client options: persistSession: true, autoRefreshToken: true.
    •    Never embed Service Role key in the app (use Anon key only).
    •    Call DB only when a session exists (if required by RLS).
    •    Use precise projection: avoid select("*") unless necessary; select explicit columns.
    •    When expecting 1 row use .single(); otherwise use .limit(1) and pick .first.
    •    Filter items by list_id and respect RLS.
    •    Do not send owner_id from the client when server policies/trigger infer it.
    •    Handle not found vs real errors distinctly (e.g., fetch default list → create if not found; otherwise rethrow).

Localization & Accessibility
    •    Use LocalizedStringKey for user-facing text; avoid hard-coded strings.
    •    Provide meaningful accessibilityLabel where appropriate.

⸻

📝 Git Workflow & Commit Conventions

Commit Rules
    •    No commits or pushes unless I explicitly request and confirm.
    •    Commit messages must follow the format:
[PREFIX](optional-scope): short message
    •    Use present tense and imperative mood:
✅ “Fix layout bug”
❌ “Fixed layout bug” or “Fixes layout bug”

Commit Prefixes & Meaning

Component    Prefix    Description
🚀 Features & Changes    FEAT    New feature / functionality
    ENHANCE    Improvement of existing features (non-breaking)
🛠️ Code Quality & Refactors    REFACTOR    Code restructuring without behavior change
    STYLE    Formatting, whitespace, code style (no logic change)
    PERF    Performance optimization
🐛 Bug Fixing    FIX    Bugfix
    HOTFIX    Critical bugfix, usually directly on main
📚 Documentation    DOCS    Documentation changes (README, comments, wiki)
🧪 Testing    TEST    Add or modify tests
🔧 Build & Infra    BUILD    Build system changes (e.g., Xcode, SwiftPM, Docker)
    CI    CI/CD changes (GitHub Actions, pipelines)
⚙️ Misc    CHORE    Maintenance (deps update, cleanup, no functional change)

Commit Style Example

STYLE(ProductImageFullscreenView): Align modal header with EditItemView

- Match header title and xmark dismiss button styling to EditItemView
- Use identical top and horizontal padding for consistent visual appearance
- Ensure accent color and font size are the same as EditItemView

#UI #consistency

✅ Commit Checklist
    •    Correct prefix chosen?
    •    (Optional) Scope added? (FEAT(auth): Add login flow)
    •    Short, precise title in present tense
    •    (Optional) Description with details
    •    (Optional) BREAKING CHANGE: note if API/model/behavior changed
    •    (Optional) Footer with Issue reference (Fixes #123, Refs JIRA-456)

⸻

❌ Don’t
    •    Don’t use UIKit.
    •    Don’t skip comments on any line.
    •    Don’t commit or push without explicit approval.
    •    Don’t use unclear or abbreviated names.
    •    Don’t break MVVM separation.
    •    Don’t put UI/business logic in GroceryGeniusApp.swift.
    •    Don’t perform DB calls in Views or the App file.
    •    Don’t swallow errors or print in production; surface via ViewModel and UI.
    •    Don’t block threads or use DispatchSemaphore in app code.
    •    Don’t use unscoped/unclear commit messages.
