//
//  AsyncView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/24.
//

import SwiftUI
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
