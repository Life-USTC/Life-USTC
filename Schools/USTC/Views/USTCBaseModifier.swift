//
//  USTCBaseModifier.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import SwiftUI

struct USTCBaseModifier: ViewModifier {
    @LoginClient(.ustcCAS) var ustcCasClient: UstcCasClient

    @State private var presenterInjected = false

    func body(content: Content) -> some View {
        content
            // Inject a presenter for background login when no explicit sheet is up
            .background(
                PresenterInjectorView(onResolve: { vc in
                    guard !presenterInjected else { return }
                    ustcCasClient.setPresenter(vc)
                    presenterInjected = true
                })
                .frame(width: 0, height: 0)
            )
    }
}

// MARK: - Presenter Injector (shared helper)
struct PresenterInjectorView: UIViewControllerRepresentable {
    var onResolve: (UIViewController) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        Resolver(onResolve: onResolve)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    private final class Resolver: UIViewController {
        let onResolve: (UIViewController) -> Void

        init(onResolve: @escaping (UIViewController) -> Void) {
            self.onResolve = onResolve
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            onResolve(self)
        }
    }
}
