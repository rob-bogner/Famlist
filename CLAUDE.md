# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**GroceryGenius** is an iOS shopping list app built with SwiftUI and Firebase Firestore. The app provides real-time synchronization of shopping items across devices with a clean, gesture-based interface.

## Development Commands

### Building and Running
```bash
# Open the project in Xcode
open GroceryGenius.xcodeproj

# Build from command line (if xcodebuild is available)
xcodebuild -project GroceryGenius.xcodeproj -scheme GroceryGenius -configuration Debug build

# Clean build folder
xcodebuild clean -project GroceryGenius.xcodeproj -scheme GroceryGenius
```

### Firebase Configuration
- The app requires `GoogleService-Info.plist` to be present in the root directory
- Firebase is initialized in `GroceryGeniusApp.swift` on app launch
- Firestore collection name: `"items"`

## Architecture

### MVVM Pattern
The app follows the Model-View-ViewModel pattern:

**Models** (`GroceryGenius/Models/`)
- `ItemModel`: Core data structure representing a shopping item
  - Properties: `id`, `image`, `name`, `units`, `measure`, `price`, `isChecked`
  - Conforms to `Identifiable`, `Hashable`, `Codable`

**ViewModels** (`GroceryGenius/ViewModels/`)
- `ListViewModel`: Main view model managing shopping list state
  - Uses `@Published` properties for reactive UI updates
  - Delegates all data operations to `FirestoreManager`
  - Provides computed properties for progress tracking (`progressFraction`, `checkedItemCount`, etc.)
  - Maintains a real-time Firestore listener that updates `items` array

**Views** (`GroceryGenius/Views/`)
- `ShoppingListView`: Root view with navigation and layout structure
- `ListView`: Main list display with swipe actions and sections for checked/unchecked items
- `AddItemView`: Modal sheet for adding new items (minimal form with just name field)
- `EditItemView`: Modal sheet for editing existing items
- `ListRowView`: Custom row component for displaying individual items
- `ShoppingListProgressView`: Progress indicator showing completion status

**Services** (`GroceryGenius/Service/`)
- `FirestoreManager`: Singleton managing all Firestore operations
  - Methods: `addListener()`, `addItem()`, `updateItem()`, `deleteItem()`
  - Uses real-time snapshot listeners for automatic UI updates
  - All operations use the `items` collection in Firestore

### Data Flow
1. `FirestoreManager` establishes real-time listener to Firestore
2. Changes trigger callbacks to `ListViewModel`
3. `ListViewModel` updates `@Published` properties
4. SwiftUI views automatically re-render
5. User actions in views call `ListViewModel` methods
6. `ListViewModel` delegates to `FirestoreManager`
7. Firestore updates propagate back through listener

### Theming System
Custom theming implemented via `Color` extension (`GroceryGenius/Extensions/Color.swift`):
- Colors defined in asset catalog (`GroceryGenius/Assets.xcassets/ThemeColors/`)
- Access via `Color.theme.background`, `Color.theme.card`, etc.
- Theme colors: `accent`, `background`, `card`, `shadow`, `buttonFillColor`, `buttonIconColor`

### SwiftUI Patterns Used
- `@EnvironmentObject` for dependency injection (ListViewModel shared across views)
- `@Published` properties for reactive state management
- `.sheet()` modifier for modal presentations with custom detents
- Custom swipe actions (`.swipeActions()`) for item interactions
- `@State` and `@FocusState` for local view state
- Preview providers (`#Preview`) for SwiftUI canvas

## File Organization
```
GroceryGenius/
├── Models/           # Data models (ItemModel)
├── Views/            # SwiftUI views
├── ViewModels/       # View models (ListViewModel)
├── Service/          # Backend services (FirestoreManager)
├── Extensions/       # Swift extensions (Color theme)
├── MockData/         # Sample data for development/previews
├── Assets.xcassets/  # Images, colors, and app icon
└── GroceryGeniusApp.swift  # App entry point

GroceryGenius.xcodeproj/  # Xcode project configuration
GoogleService-Info.plist  # Firebase configuration (root level)
```

## Key Implementation Details

### Swipe Actions in ListView
- **Trailing edge (unchecked items)**: "Not available" (orange), "Edit" (blue), "Delete" (red)
- **Leading edge (unchecked items)**: "Check" (green) - full swipe enabled
- **Trailing edge (checked items)**: "Uncheck" (yellow) - full swipe enabled
- **Leading edge (checked items)**: "Delete" (red) - full swipe enabled

### Modal Presentations
- `AddItemView`: `.height(150)` detent, 15pt corner radius
- `EditItemView`: `.height(400)` detent, 15pt corner radius

### Progress Tracking
`ListViewModel` provides computed properties:
- `totalItemCount`: Total items in list
- `checkedItemCount`: Number of checked items
- `progressFraction`: Completion percentage (0.0 to 1.0)
- `uncheckedItems`: Filtered array of unchecked items
- `checkedItems`: Filtered array of checked items

## Development Notes

### When Adding New Features
1. Models should conform to `Codable` for Firestore serialization
2. Use `FirestoreManager.shared` for all database operations
3. Maintain separation: Views → ViewModel → Service
4. Add `#Preview` providers for new views
5. Use `Color.theme.*` for consistent theming
6. Wrap state changes in `withAnimation { }` for smooth transitions

### Firebase/Firestore Integration
- All items stored in single collection: `"items"`
- Document ID matches `ItemModel.id` (UUID string)
- Real-time updates via snapshot listeners
- Error handling logs to console with emoji prefixes (⚠️, ❌)

### MockData Usage
`MockData.swift` provides sample items for:
- SwiftUI previews
- Development without Firestore connection
- Testing UI layouts
- Reference for creating new items

## Common Pitfalls
- Don't forget to call `FirebaseApp.configure()` before using Firestore
- Always update items through `ListViewModel`, not directly via `FirestoreManager`
- Modal sheets need `environmentObject(listViewModel)` to access shared state
- Color theme names must match asset catalog entries exactly
