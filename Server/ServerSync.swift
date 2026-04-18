//
//  ServerSync.swift
//  Life@USTC
//
//  Created on 2026/4/17.
//

import Foundation
import SwiftData
import SwiftUI

/// Handles syncing scraped data from USTC official sources to the server.
///
/// The iOS client is the only actor that can scrape *.ustc.edu.cn (requires student
/// credentials). After scraping, it pushes the data to the server backend so
/// other clients and features (comments, descriptions, etc.) can reference it.
enum ServerSync {

    // MARK: - Curriculum Sync

    /// After scraping curriculum from jw.ustc.edu.cn, match section codes
    /// with the server and subscribe the user to those sections.
    ///
    /// This is best-effort: failures are logged but don't interrupt the user.
    @MainActor
    static func syncCurriculumInBackground() {
        guard ServerClient.shared.isAuthenticated else { return }
        guard !SwiftDataStack.isPresentingDemo else { return }

        Task.detached(priority: .utility) {
            do {
                try await syncCurriculum()
            } catch {
                AppLogger.shared.error(
                    "Curriculum sync failed: \(error.localizedDescription)",
                    category: "ServerSync"
                )
            }
        }
    }

    /// Core sync logic: extract section codes from local data, match with server,
    /// and subscribe.
    static func syncCurriculum() async throws {
        let lessonCodes = await extractLessonCodes()
        guard !lessonCodes.isEmpty else { return }

        let matchResponse: MatchCodesResponse =
            try await ServerClient.shared.request(
                .matchCodes(
                    MatchCodesRequest(
                        codes: lessonCodes,
                        semesterId: nil
                    ))
            )

        let sectionIds = matchResponse.sections.map(\.id)
        guard !sectionIds.isEmpty else { return }

        let _: CalendarSubscriptionResponse =
            try await ServerClient.shared.request(
                .updateSubscriptions(
                    UpdateSubscriptionRequest(sectionIds: sectionIds)
                )
            )

        UserDefaults.appGroup.set(
            Date(),
            forKey: "lastCurriculumSyncedAt"
        )
    }

    /// Extract lesson codes from local SwiftData courses.
    @MainActor
    private static func extractLessonCodes() -> [String] {
        let context = SwiftDataStack.modelContext
        let descriptor = FetchDescriptor<Course>()
        guard let courses = try? context.fetch(descriptor) else { return [] }
        return courses.compactMap { course in
            let code = course.lessonCode
            return code.isEmpty ? nil : code
        }
    }

    // MARK: - Homework Sync

    /// Placeholder for future homework push logic.
    /// Currently deferred: the scraped BB homework data lacks stable identifiers
    /// for reliable server-side deduplication. Will be implemented once a
    /// dedicated sync endpoint with idempotency support is added to the server.
    static func syncHomeworks() async throws {
        // TODO: Implement when server has a dedicated homework sync endpoint
        // with idempotency key support (e.g., source=bb, sourceCourseKey, sourceHomeworkKey)
    }
}
