//
//  SwiftUIExtension.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import Introspect
import SwiftUI
import WidgetKit

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
}

enum TitleAndSubTitleStyle {
    case substring
    case reverse
    case caption
}

struct FailureView: View {
    var bigStyle = true
    var body: some View {
        HStack {
            Image(systemName: "xmark.circle")
                .foregroundColor(.yellow)

            if bigStyle {
                Text("Something went wrong")
            }
        }
    }
}

@available(*, deprecated)
struct TitleAndSubTitle: View {
    var title: String
    var subTitle: String
    var style: TitleAndSubTitleStyle

    var body: some View {
        VStack(alignment: .leading) {
            switch style {
            case .substring:
                Text(title)
                    .font(.body)
                    .bold()
                    .padding(.bottom, 1)
                Text(subTitle)
                    .font(.caption)
            case .reverse:
                Text(subTitle)
                    .foregroundColor(.secondary)
                    .fontWeight(.semibold)
                Text(title)
                    .font(.title2)
                    .bold()
            case .caption:
                Text(title)
                    .font(.title2)
                    .bold()
                Text(subTitle)
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .bold()
            }
        }
        .hStackLeading()
    }

    init(title: String, subTitle: String, style: TitleAndSubTitleStyle) {
        self.title = NSLocalizedString(title, comment: "")
        self.subTitle = NSLocalizedString(subTitle, comment: "")
        self.style = style
    }
}

@available(*, deprecated)
struct ListLabelView: View {
    var image: String
    var title: String
    var subTitle: String

    var body: some View {
        HStack {
            Image(systemName: image)
                .frame(width: 30)
                .foregroundColor(.accentColor)
                .symbolRenderingMode(.hierarchical)
            if subTitle.isEmpty {
                Text(title)
                    .bold()
            } else {
                TitleAndSubTitle(title: title, subTitle: subTitle, style: .substring)
            }
            Spacer()
        }
    }
}

@available(*, deprecated)
struct BigButtonStyle: ButtonStyle {
    var size: CGFloat = 1.0
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
#if os(iOS)
            .foregroundColor(.white)
            .background {
                RoundedRectangle(cornerRadius: 10 * size)
                    .fill(Color.accentColor)
                    .frame(width: 250 * size, height: 50 * size)
            }
            .padding()
#endif
    }
}

@available(*, deprecated)
struct ViewOffsetKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue = CGFloat.zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

extension Color {
    /// Generate the color from hash value
    ///
    /// - Note: Output color matches following range:
    ///   hue: .random(in: 0...1)
    ///   saturation: .random(in: 0.25...0.55)
    ///   brightness: .random(in: 0.25...0.35, 0.75...0.85)
    @available(*, deprecated)
    init(with string: String, mode: ColorScheme) {
        let hash = Int(string.md5HexString.prefix(6), radix: 16)!
        let hue = Double(hash % 360) / 360
        let saturation = Double(hash % 30 + 25) / 100
        var brightness = 0.0
        if mode == .dark {
            brightness = Double(hash % 10 + 25) / 100
        } else {
            brightness = Double(hash % 10 + 75) / 100
        }
#if os(iOS)
        self = Color(uiColor: UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1))
#else
        self = Color(nsColor: NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1))
#endif
    }
}

extension WidgetFamily: CaseIterable {
    public static var allCases: [WidgetFamily] {
#if os(iOS)
        [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .accessoryRectangular, .accessoryInline]
#else
        [.systemSmall, .systemMedium, .systemLarge]
#endif
    }
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
