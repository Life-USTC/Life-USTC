//
//  SwiftUIExtension.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import Introspect
import SwiftUI

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

struct AsyncView<D>: View {
    @State var status: AsyncViewStatus = .inProgress
    @State var data: D?
    var makeView: (D) -> AnyView
    var loadData: (() async throws -> D)?
    var refreshData: (() async throws -> D)?

    var asyncDataDelegate: (any AsyncDataDelegate)?
    var showReloadButton: Bool = true

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

    init<AsyncDataDelegateType: AsyncDataDelegate>
    (delegate: AsyncDataDelegateType,
     showReloadButton: Bool = true,
     makeView: @escaping (D) -> any View) where
        AsyncDataDelegateType.D == D
    {
        asyncDataDelegate = delegate
        self.showReloadButton = showReloadButton
        self.makeView = { AnyView(makeView($0)) }
    }

    func makeMainView(with providedData: D) -> some View {
        if asyncDataDelegate != nil, showReloadButton {
            return AnyView(makeView(providedData)
                .toolbar {
                    Button {
                        // TODO: Not fully testedprovidedData
                        Task {
                            try await asyncDataDelegate?.forceUpdate()
                            data = try await asyncDataDelegate?.parseCache() as? D
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                })
        }
        if refreshData == nil || asyncDataDelegate != nil {
            return makeView(providedData)
        }
        return AnyView(
            makeView(providedData)
                .toolbar {
                    Button {
                        asyncBind($data, status: $status, refreshData!)
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                })
    }

    var body: some View {
        Group {
            switch status {
            case .inProgress:
                ProgressView()
            case .success:
                makeMainView(with: data!)
            case .cached:
                makeMainView(with: data!)
            case .failure:
                FailureView()
            case .waiting:
                EmptyView()
            }
        }
        .onAppear {
            if loadData != nil {
                asyncBind($data, status: $status, loadData!)
            } else {
                asyncDataDelegate?.asyncBind($data, status: $status)
            }
        }
    }
}

struct AsyncButton: View {
    var function: () async throws -> Void
    var makeView: (AsyncViewStatus) -> AnyView
    @State var status = AsyncViewStatus.waiting
    var bigStyle = true

    init(bigStyle: Bool = true, function: @escaping () async throws -> Void, label: @escaping (AsyncViewStatus) -> any View) {
        self.function = function
        makeView = { AnyView(label($0)) }
        self.bigStyle = bigStyle
    }

    var mainView: some View {
        Button {
            asyncBind(.constant(()), status: $status) {
                try await function()
            }
        } label: {
            switch status {
            case .waiting:
                // Idle mode:
                makeView(.waiting)
            case .cached:
                // TODO: Why should a button have a status of cached??
                if bigStyle {
                    makeView(.success)
                } else {
                    Image(systemName: "checkmark")
                }
            case .success:
                if bigStyle {
                    makeView(.success)
                } else {
                    Image(systemName: "checkmark")
                }
            case .inProgress:
                if bigStyle {
                    makeView(.inProgress)
                } else {
                    ProgressView()
                }
            case .failure:
                FailureView(bigStyle: bigStyle)
            }
        }
    }

    var body: some View {
        if bigStyle {
            mainView
#if os(iOS)
            .foregroundColor(.white)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(status == .inProgress ? Color.gray : Color.accentColor)
                    .frame(width: 250, height: 50)
            }
            .padding()
#endif
        } else {
            mainView
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

@ViewBuilder func NavigationLinkAddon(_ label: LocalizedStringKey, destination: some View) -> some View {
#if os(iOS)
    if UIDevice.current.userInterfaceIdiom == .phone {
        NavigationLink {
            destination
        } label: {
            Text(label)
        }
    } else {
        Button {
            GlobalNavigation.main.updateDetailView(AnyView(destination))
        } label: {
            Text(label)
        }
    }
#else
    Text(label)
        .onTapGesture {
            GlobalNavigation.main.updateDetailView(AnyView(destination))
        }
#endif
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
        Button {
            GlobalNavigation.main.updateDetailView(AnyView(destination()))
        } label: {
            label()
        }
    }
#else
    label()
        .onTapGesture {
            GlobalNavigation.main.updateDetailView(AnyView(destination()))
        }
#endif
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
    func navigationBarTitle(_ title: LocalizedStringKey, displayMode _: NavigationBarItem.TitleDisplayMode) -> some View {
        navigationTitle(Text(title))
    }

    func navigationBarTitle(_ title: String, displayMode _: NavigationBarItem.TitleDisplayMode) -> some View {
        navigationTitle(Text(title))
    }
}
#endif

struct AsyncButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            AsyncButton {} label: { status in
                HStack {
                    Text("Check")
                    if status == .success {
                        Image(systemName: "checkmark")
                    }
                }
            }

            AsyncButton {
                throw BaseError.runtimeError("!!!")
            } label: { status in
                HStack {
                    Text("Check")
                    if status == .success {
                        Image(systemName: "checkmark")
                    }
                }
            }
            HStack {
                AsyncButton(bigStyle: false) {} label: { _ in
                    Image(systemName: "square.and.arrow.down")
                }

                AsyncButton(bigStyle: false) {
                    throw BaseError.runtimeError("!!!")
                } label: { _ in
                    Image(systemName: "square.and.arrow.down")
                }
            }
            .font(.largeTitle)
            .padding()
        }
    }
}
