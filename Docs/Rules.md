# Rules

## Delegates

If delegate is shared around the app, (but shall all be refrencing the same object), consider:

1. No stored properties, and use struct instead of class
2. Use `static let shared = ...` to create a singleton

## Class

Variables used in class shall be sorted in this order:

1. `static let`
2. `@PropertyWrapper`
3. `var`

For variables only used in one function, consider moving the variable inside the function. If not possible, you could also write just before the function.

## Protocols

When following protocols, this order is used:

1. System protocols, examples: `Codable`, `Equatable`
2. Custom protocols, examples: `ExampleDataProtocol`

## Files

Files shall be kept small in size, relatively easy to read.

If a file is too long, consider splitting it into multiple files (under the same folder).

## Functions

Use less `func B() -> B`, but rather:

```swift
extension B {
    convience init(_ a: A) {
        // ...
    }
}
```

## SwiftUI

Apply modifiers in this order:

* `font`
* `foregroundColor` / `fill`
* `grayscale`
* `resizable`
* `frame`
* `redacted` / `blur`
* `onTapGesture`
