## Instructions

## SwiftUI

- Be declarative, write logic (serach, filter) in computed properties, NOT in the body:
  - Good: `var filteredItems: [Item] { items.filter { $0.isActive } }`
  - Bad: `var body: some View { let filteredItems = items.filter { $0.isActive }; return List(filteredItems) { ... } }`
- Use `@State` for local state, `@Binding` for parent-child communication, `@ObservedObject` or `@StateObject` for view models.
  - Avoid unecessary private marking
  - Sort variables in this order:
    - `@ManagedData`: a custom property wrapper for data fetching
    - `@AppStorage` & `@AppSecureStorage`
    - `@State`
    - `@Binding`
    - `@ObservedObject` & `@StateObject`
    - Computed properties
    - Regular properties(like titles, that should be passed in init)
    - remove unused variables
    - remove unnecessary inits
- Use `NavigationStack` and `NavigationLink` for navigation.
- Use `.searchable(text:)` for search bars.
- Use `.sheet(isPresented:)` for modals.
  - Always pass in a dismiss action (on the top-left) to the sheet view
- Use `.toolbar` for toolbar items.
- Use `.navigationTitle` for titles, avoid `.navigationBarTitleDisplayMode(.large)`
- Use `@ViewBuilder` for complex view compositions.
- Use `LazyVStack` or `LazyHStack` for large lists of views.

## Swift

- You should optimize namings and structure for better readability and SwiftUI conventions
  - remember to rename variables and functions consistently across the project.
  - for special namings like life_ustc, keep them as is.
- Use `guard` statements to reduce nesting.
  - Early return is always preferred.
- Use `if let` or `guard let` for optional unwrapping.
- Use `switch` statements for multiple conditions instead of multiple `if-else`.
- Use `map`, `filter`, `reduce` for array transformations instead of loops.
- Sort imports alphabetically and remove unused imports.
- Remove unnecessary comments and I don't suggest you add one.
  - But you should always keep the file header comments.
- Remove unnecessary `self.`.
- Expand $0 and $1 to meaningful names in closures if it improves readability.

## Project Maintenance

- Run XcodeGen if you add new files, or edit project.yml:
  - `xcodegen --spec project.yml`
- Make sure the project builds successfully after your changes:
  - `xcodebuild -project "Life-USTC.xcodeproj" -scheme "Life-USTC" -configuration Debug -quiet build`
- Format the code using swift-format:
  - `swift-format format -i <file-path>`
- Commit changes with clear messages, use conventional commit style if possible.
  - e.g., `feat: add search functionality to item list`, make the commit message short but informative.
