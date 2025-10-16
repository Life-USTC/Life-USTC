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
    Binding(get: { lhs.wrappedValue ?? rhs }, set: { lhs.wrappedValue = $0 })
}

prefix func ! <T>(lhs: Binding<T?>) -> Binding<T> {
    Binding(get: { lhs.wrappedValue! }, set: { lhs.wrappedValue = $0 })
}

struct FlipableCard: View {
    @Binding var flipped: Bool
    var flippedDegrees: Double { flipped ? 180 : 0 }

    var mainView: () -> any View
    var settingsView: () -> any View

    var body: some View {
        ZStack {
            AnyView(mainView())
                .card()
                .flipRotate(flippedDegrees)
                .opacity(flipped ? 0 : 1)

            AnyView(settingsView())
                .card()
                .flipRotate(-180 + flippedDegrees)
                .opacity(flipped ? 1 : 0)
        }
    }
}

extension View {
    func hStackTrailing() -> some View {
        HStack {
            Spacer()
            self
        }
    }

    func hStackLeading() -> some View {
        HStack {
            self
            Spacer()
        }
    }

    func edgesIgnoringHorizontal(_: Edge.Set) -> some View {
        self
    }

    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`(
        _ condition: Bool,
        transform: (Self) -> some View
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    func card() -> some View {
        self
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color("BackgroundWhite"))
            }
    }

    func flipRotate(_ degrees: Double) -> some View {
        rotation3DEffect(
            Angle(degrees: degrees),
            axis: (x: 0.0, y: 1.0, z: 0.0)
        )
    }

    func widgetBackground(_ backgroundView: some View) -> some View {
        if #available(iOSApplicationExtension 17.0, iOS 17, *) {
            AnyView(
                containerBackground(for: .widget) {
                    backgroundView
                }
            )
        } else {
            AnyView(background(backgroundView))
        }
    }
}

extension WidgetFamily: @retroactive CaseIterable {
    public static var allCases: [WidgetFamily] = [
        .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge,
        .accessoryRectangular, .accessoryInline, .accessoryCircular,
    ]
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(
            in: CharacterSet.alphanumerics.inverted
        )
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (
                255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17
            )
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (
                int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF
            )
        default: (a, r, g, b) = (1, 1, 1, 0)
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

struct RandomNumberGeneratorWithSeed: RandomNumberGenerator {
    init(seed: Int) { srand48(seed) }
    func next() -> UInt64 { UInt64(drand48() * Double(UInt64.max)) }
}

@available(*, deprecated, message: "NOT recommended to use.")
let exampleGradientList: [[Color]] = [
    [.init(hex: "#6A95A9"), .init(hex: "#4577C7")],
    [.init(hex: "#9AE0E9"), .init(hex: "#89AFE8")],
    [.init(hex: "#C298E5"), .init(hex: "#759BDC")],
    [.init(hex: "#9999E5"), .init(hex: "#A7E6E2")],
    [.init(hex: "#F3C981"), .init(hex: "#89CD7D")],
    [.init(hex: "#3D6585"), .init(hex: "#99D587")],
    [.init(hex: "#D5AF8D"), .init(hex: "#6FA3A3")],
]

struct EqualWidthHStack: Layout {
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {

        let maxSize = maxSize(subviews: subviews)
        let spacing = spacing(subviews: subviews)
        let totalSpacing = spacing.reduce(0.0, +)

        return CGSize(
            width: maxSize.width * CGFloat(subviews.count) + totalSpacing,
            height: maxSize.height
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {

        let maxSize = maxSize(subviews: subviews)
        let spacing = spacing(subviews: subviews)

        let sizeProposal = ProposedViewSize(
            width: maxSize.width,
            height: maxSize.height
        )

        var x = bounds.minX + maxSize.width / 2

        for index in subviews.indices {
            subviews[index]
                .place(
                    at: CGPoint(x: x, y: bounds.midY),
                    anchor: .center,
                    proposal: sizeProposal
                )
            x += maxSize.width + spacing[index]
        }
    }

    private func spacing(subviews: Subviews) -> [CGFloat] {
        subviews.indices.map { index in
            guard index < subviews.count - 1 else { return 0.0 }

            return subviews[index].spacing
                .distance(
                    to: subviews[index + 1].spacing,
                    along: .horizontal
                )
        }
    }

    private func maxSize(subviews: Subviews) -> CGSize {
        let subviewSizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let maxSize: CGSize = subviewSizes.reduce(
            .zero,
            { result, size in
                CGSize(
                    width: max(result.width, size.width),
                    height: max(result.height, size.height)
                )
            }
        )

        return maxSize
    }
}

struct DeviceRotationViewModifier: ViewModifier {
    let action: (UIDeviceOrientation) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                action(UIDevice.current.orientation)
            }
    }
}

// A View wrapper to make the modifier easier to use
extension View {
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.modifier(DeviceRotationViewModifier(action: action))
    }
}

struct RoundedCornersShape: Shape {
    let corners: UIRectCorner
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
