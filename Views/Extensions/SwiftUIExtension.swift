//
//  SwiftUIExtension.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import Introspect
import SwiftUI
import WidgetKit

// Optional Binding
func ?? <T>(lhs: Binding<T?>, rhs: T) -> Binding<T> {
    Binding(
        get: { lhs.wrappedValue ?? rhs },
        set: { lhs.wrappedValue = $0 }
    )
}

prefix func ! <T>(lhs: Binding<T?>) -> Binding<T> {
    Binding(
        get: { lhs.wrappedValue! },
        set: { lhs.wrappedValue = $0 }
    )
}

struct HStackModifier: ViewModifier {
    var trailing = false
    func body(content: Content) -> some View {
        HStack {
            if trailing {
                Spacer()
                content
            } else {
                content
                Spacer()
            }
        }
    }
}

extension View {
    func hStackLeading() -> some View {
        modifier(HStackModifier())
    }

    func hStackTrailing() -> some View {
        modifier(HStackModifier(trailing: true))
    }

    func edgesIgnoringHorizontal(_: Edge.Set) -> some View {
        self
    }

    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

extension WidgetFamily: CaseIterable {
    public static var allCases: [WidgetFamily] = [
        .systemSmall,
        .systemMedium,
        .systemLarge,
        .systemExtraLarge,
        .accessoryRectangular,
        .accessoryInline,
        .accessoryCircular,
    ]
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

let exampleGradientList: [[Color]] = [
    [.init(hex: "#6A95A9"), .init(hex: "#4577C7")],
    [.init(hex: "#9AE0E9"), .init(hex: "#89AFE8")],
    [.init(hex: "#C298E5"), .init(hex: "#759BDC")],
    [.init(hex: "#9999E5"), .init(hex: "#A7E6E2")],
    [.init(hex: "#F3C981"), .init(hex: "#89CD7D")],
    [.init(hex: "#3D6585"), .init(hex: "#99D587")],
    [.init(hex: "#D5AF8D"), .init(hex: "#6FA3A3")],
]
