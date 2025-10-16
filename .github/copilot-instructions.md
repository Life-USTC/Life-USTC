## Instructions for SwiftUI code:

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
  - Always pass in a dismiss action to the sheet view
- Use `.toolbar` for toolbar items.
- Use `.navigationTitle` for titles, avoid `.navigationBarTitleDisplayMode(.large)`

## Others

- You can also optimize namings and structure for better readability and SwiftUI conventions. But remember to rename variables and functions consistently across the project.
  - for special namings like life_ustc, keep them as is.
- Use `guard` statements to reduce nesting.
  - Early return is always preferred.
- Use `if let` or `guard let` for optional unwrapping.
- Use `switch` statements for multiple conditions instead of multiple `if-else`.
- Use `map`, `filter`, `reduce` for array transformations instead of loops.
- Use `forEach` for iterating over collections in SwiftUI views.
- Use `@ViewBuilder` for complex view compositions.
- Use `LazyVStack` or `LazyHStack` for large lists of views.
- Sort imports alphabetically and remove unused imports.
- Remove unnecessary comments and I don't suggest you add one.
  - But you should always keep the file header comments.
- Remove unnecessary `self.`.
- Expand $0 and $1 to meaningful names in closures.
- Run `xcodebuild -project "学在科大.xcodeproj" -scheme "学在科大" -configuration Debug -quiet build && echo "BUILD SUCCEEDED" || echo "BUILD FAILED"` to see if the code compiles.
- Run `swift-format format -i $filePath` to format the code.
