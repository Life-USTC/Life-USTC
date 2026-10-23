import SwiftUI

@Observable
@MainActor
final class ServerHomeworkEditorModel {
    let sectionJwId: Int
    var title: String
    var description: String
    var publishedAt: Date?
    var submissionStartAt: Date?
    var submissionDueAt: Date?
    var isMajor: Bool
    var requiresTeam: Bool
    private(set) var isLoadingPermissions = false
    private(set) var isSaving = false
    private(set) var permissionError: String?
    private(set) var error: String?
    private(set) var hasSaved = false

    private let original: ServerHomework?
    private let client: ServerClient
    private let revision: UUID
    private var permissionSnapshot: ServerHomeworkViewer?
    private var permissionsResolved = false
    private var savedSnapshot: ServerHomework?
    private var generation = 0

    init(sectionJwId: Int, homework: ServerHomework? = nil, client: ServerClient = .shared) {
        self.sectionJwId = sectionJwId
        original = homework
        self.client = client
        revision = client.sessionRevision
        title = homework?.title ?? ""
        description = homework?.description?.content ?? ""
        publishedAt = homework?.publishedAt
        submissionStartAt = homework?.submissionStartAt
        submissionDueAt = homework?.submissionDueAt
        isMajor = homework?.isMajor ?? false
        requiresTeam = homework?.requiresTeam ?? false
    }

    var isEditing: Bool { original != nil }
    var isCurrentSession: Bool { client.isAuthenticated && revision == client.sessionRevision }
    var viewer: ServerHomeworkViewer? { isCurrentSession ? permissionSnapshot : nil }
    var savedHomework: ServerHomework? { isCurrentSession ? savedSnapshot : nil }

    var canEdit: Bool {
        isCurrentSession && permissionsResolved && !isLoadingPermissions && permissionError == nil
            && viewer?.isAuthenticated == true && viewer?.isSuspended == false
            && original?.deletedAt == nil
    }

    var validationError: String? {
        if normalizedTitle.isEmpty { return String(localized: "Enter a title.") }
        if normalizedTitle.utf16.count > 200 {
            return String(localized: "The title must be 200 characters or fewer.")
        }
        if normalizedDescription.utf16.count > 4000 {
            return String(localized: "The description must be 4,000 characters or fewer.")
        }
        if let submissionStartAt, let submissionDueAt, submissionStartAt > submissionDueAt {
            return String(localized: "Submission start must be on or before the deadline.")
        }
        return nil
    }

    var hasChanges: Bool {
        guard let original else { return true }
        return normalizedTitle != original.title
            || normalizedDescription != ServerCommunityText.trim(original.description?.content ?? "")
            || publishedAt != original.publishedAt || submissionStartAt != original.submissionStartAt
            || submissionDueAt != original.submissionDueAt || isMajor != original.isMajor
            || requiresTeam != original.requiresTeam
    }

    var canSave: Bool {
        canEdit && !isSaving && !hasSaved && validationError == nil && hasChanges
    }

    func loadPermissions() async {
        generation += 1
        let requestGeneration = generation
        permissionsResolved = false
        permissionError = nil
        guard isCurrentSession else {
            permissionSnapshot = nil
            isLoadingPermissions = false
            return
        }
        isLoadingPermissions = true
        defer {
            if requestGeneration == generation {
                isLoadingPermissions = false
                if !isCurrentSession { permissionSnapshot = nil }
            }
        }
        do {
            let response = try await client.fetchSectionHomeworks(sectionJwId: sectionJwId, page: 1, pageSize: 1)
            guard requestGeneration == generation, isCurrentSession, !Task.isCancelled else { return }
            permissionSnapshot = response.meta.viewer
            permissionsResolved = true
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, isCurrentSession, !Task.isCancelled else { return }
            permissionError = error.localizedDescription
        }
    }

    @discardableResult
    func save() async -> Bool {
        guard !isSaving, !hasSaved else { return false }
        guard canEdit else {
            error = String(localized: "Refresh permissions before editing shared homework.")
            return false
        }
        if let validationError {
            error = validationError
            return false
        }
        guard hasChanges else { return false }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            let saved: ServerHomework
            if let original {
                saved = try await client.updateHomework(
                    id: original.id, request: updateRequest(original), expectedRevision: revision
                )
            } else {
                saved = try await client.createHomework(CreateHomeworkRequest(
                    sectionJwId: sectionJwId, title: normalizedTitle,
                    description: normalizedDescription.isEmpty ? nil : normalizedDescription,
                    publishedAt: publishedAt.map(Self.encodeDate),
                    submissionStartAt: submissionStartAt.map(Self.encodeDate),
                    submissionDueAt: submissionDueAt.map(Self.encodeDate),
                    isMajor: isMajor, requiresTeam: requiresTeam
                ), expectedRevision: revision)
            }
            guard isCurrentSession, !Task.isCancelled else { return false }
            savedSnapshot = saved
            hasSaved = true
            return true
        } catch is CancellationError {
            return false
        } catch {
            guard isCurrentSession, !Task.isCancelled else { return false }
            self.error = error.localizedDescription
            return false
        }
    }

    private var normalizedTitle: String { ServerCommunityText.trim(title) }
    private var normalizedDescription: String { ServerCommunityText.trim(description) }

    private static func encodeDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func updateRequest(_ original: ServerHomework) -> UpdateHomeworkRequest {
        func changedDate(_ date: Date?, from previous: Date?) -> ServerPatchValue<String> {
            date == previous ? .unchanged : date.map { .value(Self.encodeDate($0)) } ?? .null
        }
        let content: ServerPatchValue<String> = normalizedDescription == ServerCommunityText.trim(original.description?.content ?? "")
            ? .unchanged : normalizedDescription.isEmpty ? .null : .value(normalizedDescription)
        return UpdateHomeworkRequest(
            title: normalizedTitle == original.title ? nil : normalizedTitle,
            description: content, publishedAt: changedDate(publishedAt, from: original.publishedAt),
            submissionStartAt: changedDate(submissionStartAt, from: original.submissionStartAt),
            submissionDueAt: changedDate(submissionDueAt, from: original.submissionDueAt),
            isMajor: isMajor == original.isMajor ? nil : isMajor,
            requiresTeam: requiresTeam == original.requiresTeam ? nil : requiresTeam
        )
    }
}
