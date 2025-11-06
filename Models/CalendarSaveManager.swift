//
//  CalendarSaveManager.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2025/11/06.
//

import Foundation

actor CalendarSaveManager {
    static let shared = CalendarSaveManager()

    private var isSaving = false

    func executeSave(_ operation: @Sendable @escaping () async throws -> Void) async throws {
        guard !isSaving else {
            throw BaseError.runtimeError("Calendar save already in progress")
        }

        isSaving = true
        defer { isSaving = false }

        try await operation()
    }
}
