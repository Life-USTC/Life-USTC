//
//  InAppNotification.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/12.
//

import SwiftUI

struct InAppNotification: Identifiable, Equatable {
    var id = UUID()

    /// You're not supposed to use white/black with this.
    var color: Color
    var message: String

    /// Provide nil for the message to persist unless user manually close it
    var expireDate: Date?

    var infolabel: String = "exclamationmark.triangle"
    var infoMessage: String = "Warning"
}

class InAppNotificationDelegate: ObservableObject {
    static var shared: InAppNotificationDelegate = .init()
    @Published var notifications: [InAppNotification] = []

    func addErrorMessage(_ message: String) {
        DispatchQueue.main.async {
            withAnimation {
                self.notifications.append(InAppNotification(color: .red, message: message))
            }
        }
    }

    func addError(_ error: Error) {
        addErrorMessage(error.localizedDescription)
    }

    func removeNotification(_ notification: InAppNotification) {
        DispatchQueue.main.async {
            withAnimation {
                self.notifications.removeAll(where: { $0 == notification })
            }
        }
    }
}
