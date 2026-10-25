import SwiftUI

@Observable
@MainActor
final class ServerSubscriptionImportModel {
    var input = "" {
        didSet { if input != oldValue { invalidatePreview() } }
    }
    var semesterID: Int? {
        didSet { if semesterID != oldValue { invalidatePreview() } }
    }
    private(set) var isLoading = false
    private(set) var isMatching = false
    private(set) var isImporting = false
    private(set) var error: String?
    private(set) var selectedSectionIDs = Set<Int>()

    private let client: ServerClient
    private var generation = 0
    private var loadGeneration = 0
    private var loadedRevision: UUID?
    private var semesterSnapshot: [ServerSemester] = []
    private var subscriptionSnapshot: [Int: ServerSubscriptionKind] = [:]
    private var previewSnapshot: ServerSubscriptionQueryResponse?
    private var resultSnapshot: ServerSubscriptionBatchResponse?

    init(client: ServerClient = .shared) { self.client = client }

    var semesters: [ServerSemester] {
        loadedRevision == client.sessionRevision ? semesterSnapshot : []
    }

    var subscribedKinds: [Int: ServerSubscriptionKind] {
        loadedRevision == client.sessionRevision ? subscriptionSnapshot : [:]
    }

    var preview: ServerSubscriptionQueryResponse? {
        loadedRevision == client.sessionRevision ? previewSnapshot : nil
    }

    var result: ServerSubscriptionBatchResponse? {
        loadedRevision == client.sessionRevision ? resultSnapshot : nil
    }

    var codes: [String] { ServerSubscriptionCodeParser.extractCodes(from: input) }

    var inputError: String? {
        if semesterID == nil { return String(localized: "Choose a semester before matching codes.") }
        if codes.isEmpty { return String(localized: "Paste course or teaching-section codes to preview matches.") }
        if codes.count > 500 { return String(localized: "Preview at most 500 codes at a time.") }
        return nil
    }

    var canMatch: Bool {
        client.isAuthenticated && loadedRevision == client.sessionRevision && inputError == nil
            && !isLoading && !isMatching && !isImporting
    }

    var canImport: Bool {
        preview != nil && !selectedSectionIDs.isEmpty && selectedSectionIDs.count <= 500
            && client.isAuthenticated && !isLoading && !isMatching && !isImporting
    }

    func load() async {
        let revision = client.sessionRevision
        if loadedRevision != revision {
            input = ""
            semesterID = nil
            semesterSnapshot = []
            subscriptionSnapshot = [:]
            invalidatePreview()
        }
        loadGeneration += 1
        let requestGeneration = loadGeneration
        loadedRevision = revision
        isLoading = client.isAuthenticated
        error = nil
        guard client.isAuthenticated else { return }
        defer { if requestGeneration == loadGeneration { isLoading = false } }
        do {
            async let available = client.fetchAllSemesters()
            async let current = client.fetchCurrentSemester()
            async let memberships = client.fetchLearningSubscriptions()
            let (semesters, currentSemester, subscriptions) = try await (available, current, memberships)
            guard requestGeneration == loadGeneration, revision == client.sessionRevision, !Task.isCancelled else { return }
            semesterSnapshot = semesters
            subscriptionSnapshot = Dictionary(uniqueKeysWithValues: subscriptions.map { ($0.id, $0.kind) })
            if semesterID == nil || !semesters.contains(where: { $0.id == semesterID }) {
                semesterID = semesters.contains(where: { $0.id == currentSemester.id }) ? currentSemester.id : nil
            }
        } catch {
            guard requestGeneration == loadGeneration, revision == client.sessionRevision, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }

    func match(locale: String) async {
        guard canMatch, let semesterID, let revision = loadedRevision else { return }
        generation += 1
        let requestGeneration = generation
        isMatching = true
        error = nil
        defer { if requestGeneration == generation { isMatching = false } }
        do {
            let response = try await client.querySubscriptionCodes(
                codes: codes, semesterID: semesterID, locale: locale, expectedRevision: revision
            )
            guard requestGeneration == generation, revision == client.sessionRevision, !Task.isCancelled else { return }
            previewSnapshot = response
            resultSnapshot = nil
            selectedSectionIDs = Set(response.sections.filter {
                $0.retiredAt == nil && subscriptionSnapshot[$0.id] == nil
            }.map(\.id))
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }

    func toggleSelection(_ sectionID: Int) {
        guard !isImporting, subscribedKinds[sectionID] == nil,
              preview?.sections.contains(where: { $0.id == sectionID && $0.retiredAt == nil }) == true else { return }
        if !selectedSectionIDs.insert(sectionID).inserted { selectedSectionIDs.remove(sectionID) }
    }

    func importSelection(locale: String) async {
        guard canImport, let revision = loadedRevision else { return }
        let requestGeneration = generation
        let selected = selectedSectionIDs.sorted()
        isImporting = true
        error = nil
        defer { isImporting = false }
        do {
            let result = try await client.appendMatchedSubscriptions(
                sectionIDs: selected, locale: locale, expectedRevision: revision
            )
            guard requestGeneration == generation, revision == client.sessionRevision, !Task.isCancelled else { return }
            resultSnapshot = result
            if let subscription = result.subscription {
                subscriptionSnapshot = Dictionary(uniqueKeysWithValues: subscription.sections.map { ($0.id, $0.kind) })
            }
            selectedSectionIDs = []
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }

    private func invalidatePreview() {
        generation += 1
        previewSnapshot = nil
        resultSnapshot = nil
        selectedSectionIDs = []
        isMatching = false
        error = nil
    }
}
