import SwiftUI

@Observable
@MainActor
final class ServerDescriptionModel {
    let target: ServerDescriptionTarget
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var loadError: String?
    private(set) var saveError: String?

    private let client: ServerClient
    private var snapshot: ServerDescriptionResponse?
    private var loadedRevision: UUID?
    private var permissionsResolved = false
    private var generation = 0
    private var editing = false
    private var editRevision: UUID?
    private var draftContent = ""

    init(target: ServerDescriptionTarget, client: ServerClient = .shared) {
        self.target = target
        self.client = client
    }

    private var ownsSnapshot: Bool { loadedRevision == client.sessionRevision }
    var description: ServerDescriptionContent? { ownsSnapshot ? snapshot?.description : nil }
    var history: [ServerDescriptionEdit] { ownsSnapshot ? snapshot?.history ?? [] : [] }
    var viewer: ServerCommentViewer? { ownsSnapshot ? snapshot?.viewer : nil }
    var isEditing: Bool { editing && editRevision == client.sessionRevision }

    var draft: String {
        get { isEditing ? draftContent : "" }
        set { if isEditing { draftContent = newValue } }
    }

    var canEdit: Bool {
        client.isAuthenticated && permissionsResolved && !isLoading && loadError == nil
            && viewer?.isAuthenticated == true && viewer?.isSuspended == false
    }

    var validationError: String? {
        draft.utf16.count > 4000 ? String(localized: "The description must be 4,000 characters or fewer.") : nil
    }

    var hasChanges: Bool {
        isEditing && ServerCommunityText.trim(draft) != description?.content
    }

    var canSave: Bool {
        isEditing && canEdit && !isSaving && validationError == nil && hasChanges
    }

    func load() async {
        generation += 1
        let requestGeneration = generation
        let revision = client.sessionRevision
        resetForSessionIfNeeded()
        permissionsResolved = false
        isLoading = true
        loadError = nil
        defer {
            if requestGeneration == generation {
                isLoading = false
                resetForSessionIfNeeded()
            }
        }
        do {
            let response = try await client.fetchDescription(for: target)
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            snapshot = response
            permissionsResolved = true
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            loadError = error.localizedDescription
        }
    }

    @discardableResult
    func beginEditing() -> Bool {
        guard canEdit, !isSaving, let description else { return false }
        draftContent = description.content
        editRevision = client.sessionRevision
        editing = true
        saveError = nil
        return true
    }

    func cancelEditing() {
        guard !isSaving else { return }
        editing = false
        draftContent = ""
        saveError = nil
    }

    @discardableResult
    func save() async -> Bool {
        guard isEditing, !isSaving, let revision = editRevision else { return false }
        guard canEdit else {
            saveError = String(localized: "Refresh permissions before editing this description.")
            return false
        }
        if let validationError {
            saveError = validationError
            return false
        }
        guard hasChanges else { return false }
        let submitted = draft
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            _ = try await client.upsertDescription(for: target, content: submitted, expectedRevision: revision)
            guard revision == client.sessionRevision, !Task.isCancelled else {
                resetForSessionIfNeeded()
                return false
            }
            editing = false
            draftContent = ""
            await load()
            return revision == client.sessionRevision && !Task.isCancelled
        } catch is CancellationError {
            resetForSessionIfNeeded()
            return false
        } catch {
            guard revision == client.sessionRevision, !Task.isCancelled else {
                resetForSessionIfNeeded()
                return false
            }
            saveError = error.localizedDescription
            return false
        }
    }

    private func resetForSessionIfNeeded() {
        guard loadedRevision != client.sessionRevision else { return }
        loadedRevision = client.sessionRevision
        snapshot = nil
        permissionsResolved = false
        editing = false
        editRevision = nil
        draftContent = ""
        loadError = nil
        saveError = nil
    }
}

enum ServerCommunityText {
    static func trim(_ text: String) -> String {
        // Match ECMAScript trim used by community input validation.
        let whitespace = CharacterSet(charactersIn:
            "\u{0009}\u{000A}\u{000B}\u{000C}\u{000D}\u{0020}\u{00A0}\u{1680}"
                + "\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}\u{2008}\u{2009}\u{200A}"
                + "\u{2028}\u{2029}\u{202F}\u{205F}\u{3000}\u{FEFF}")
        return text.trimmingCharacters(in: whitespace)
    }
}
