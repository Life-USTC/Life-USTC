//
//  SwiftUIExtension.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import Introspect
import SwiftUI

struct HStackLeading: ViewModifier {
    func body(content: Content) -> some View {
        HStack {
            content
            Spacer()
        }
    }
}

extension View {
    func hStackLeading() -> some View {
        modifier(HStackLeading())
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

struct BigButtonStyle: ButtonStyle {
    var size: CGFloat = 1.0
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
#if os(iOS)
            .foregroundColor(.white)
            .background {
                RoundedRectangle(cornerRadius: 10 * size)
                    .frame(width: 250 * size, height: 50 * size)
                    .foregroundColor(.accentColor)
            }
            .padding()
#endif
    }
}

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

struct FailureView: View {
    var body: some View {
        HStack {
            Image(systemName: "xmark.circle")
                .foregroundColor(.yellow)

            Text("Something went wrong")
        }
    }
}

struct AsyncView<D>: View {
    @State var status: AsyncViewStatus = .inProgress
    @State var data: D?
    var makeView: (D) -> AnyView
    var loadData: () async throws -> D
    var refreshData: (() async throws -> D)?

    init(makeView: @escaping (D) -> any View,
         loadData: @escaping () async throws -> D)
    {
        self.makeView = { AnyView(makeView($0)) }
        self.loadData = loadData
    }

    init(makeView: @escaping (D) -> any View,
         loadData: @escaping () async throws -> D,
         refreshData: @escaping () async throws -> D)
    {
        self.makeView = { AnyView(makeView($0)) }
        self.loadData = loadData
        self.refreshData = refreshData
    }

    @ViewBuilder func makeMainView(with data: D) -> some View {
        if refreshData == nil {
            makeView(data)
        } else {
            makeView(data)
                .toolbar {
                    Button {
                        asyncBind($data, status: $status, refreshData!)
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
        }
    }

    var body: some View {
        Group {
            switch status {
            case .inProgress:
                ProgressView()
            case .success:
                makeMainView(with: data!)
            case .failure:
                FailureView()
            }
        }
        .onAppear {
            asyncBind($data, status: $status, loadData)
        }
    }
}

var currentDateString: String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .none
    return dateFormatter.string(from: Date())
}

let daysOfWeek: [String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

var currentWeekDay: Int {
    let calendar = Calendar.current
    let weekday = calendar.component(.weekday, from: Date())
    return (weekday + 6) % 7
}

var currentWeekDayString: String {
    daysOfWeek[(currentWeekDay + 6) % 7]
}

// What a dirty way to make this cross-platform
class GlobalNavigation: ObservableObject {
    static var main = GlobalNavigation()
    @Published var detailView: AnyView = .init(Text("Click on left panel for more information"))

    func updateDetailView(_ newValue: AnyView) {
        detailView = newValue
        objectWillChange.send()
    }
}

@ViewBuilder func NavigationLinkAddon(_ label: String, destination: some View) -> some View {
#if os(iOS)
    if UIDevice.current.userInterfaceIdiom == .phone {
        NavigationLink {
            destination
        } label: {
            Text(label)
        }
    } else {
        Text(label)
            .onTapGesture {
                GlobalNavigation.main.updateDetailView(AnyView(destination))
            }
    }
#endif
    Text(label)
        .onTapGesture {
            GlobalNavigation.main.updateDetailView(AnyView(destination))
        }
}

@ViewBuilder func NavigationLinkAddon(_ destination: @escaping () -> some View, label: @escaping () -> some View) -> some View {
#if os(iOS)
    if UIDevice.current.userInterfaceIdiom == .phone {
        NavigationLink {
            destination()
        } label: {
            label()
        }
    } else {
        label()
            .onTapGesture {
                GlobalNavigation.main.updateDetailView(AnyView(destination()))
            }
    }
#endif
    label()
        .onTapGesture {
            GlobalNavigation.main.updateDetailView(AnyView(destination()))
        }
}

#if os(macOS)
enum NavigationBarItem {
    enum TitleDisplayMode {
        case inline
        case large
        case automatic
    }
}

extension View {
    func navigationBarTitle(_ title: String, displayMode _: NavigationBarItem.TitleDisplayMode) -> some View {
        return navigationTitle(Text(title))
    }
}
#endif
