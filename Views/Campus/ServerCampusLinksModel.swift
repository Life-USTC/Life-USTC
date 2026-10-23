import SwiftUI

@MainActor @Observable
final class ServerCampusLinksModel {
    private let client: ServerClient
    private var revision: UUID?
    private var pinSnapshot: ServerLinkPinsResponse?
    private var pinsLoaded = false
    private var failedPin: (slug: String, pinned: Bool)?
    private(set) var links: [ServerCampusLink] = []
    private(set) var isLoading = false
    private(set) var isLoadingPins = false
    private(set) var changingSlug: String?
    private(set) var error: String?
    private(set) var pinError: String?

    init(client: ServerClient = .shared) { self.client = client }

    var pinnedSlugs: [String] { revision == client.sessionRevision && client.isAuthenticated ? pinSnapshot?.pinnedSlugs ?? [] : [] }
    var maxPinnedLinks: Int? { revision == client.sessionRevision ? pinSnapshot?.maxPinnedLinks : nil }
    var canPin: Bool { client.isAuthenticated && revision == client.sessionRevision && pinsLoaded && !isLoadingPins && changingSlug == nil }
    var canRetryPin: Bool { canPin && failedPin != nil }

    func load(locale: String) async {
        if revision != client.sessionRevision {
            pinSnapshot = nil
            failedPin = nil
            pinError = nil
            changingSlug = nil
        }
        revision = client.sessionRevision
        let expectedRevision = client.sessionRevision
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let links = try await client.fetchCampusLinks(locale: locale)
            guard expectedRevision == client.sessionRevision, !Task.isCancelled else { return }
            self.links = links
        } catch is CancellationError { return }
        catch { if expectedRevision == client.sessionRevision { self.error = error.localizedDescription } }
        await loadPins()
    }

    func loadPins() async {
        guard client.isAuthenticated else { pinSnapshot = nil; return }
        let expectedRevision = client.sessionRevision
        isLoadingPins = true
        pinsLoaded = false
        pinError = nil
        defer { isLoadingPins = false }
        do {
            let response = try await client.fetchLinkPins()
            guard revision == expectedRevision, expectedRevision == client.sessionRevision, !Task.isCancelled else { return }
            pinSnapshot = response
            pinsLoaded = true
        } catch is CancellationError { return }
        catch { if expectedRevision == client.sessionRevision { pinError = error.localizedDescription } }
    }

    func setPinned(slug: String, pinned: Bool) async {
        guard canPin, let revision else { return }
        changingSlug = slug
        pinError = nil
        failedPin = nil
        defer { changingSlug = nil }
        do {
            let response = try await client.setLinkPinned(slug: slug, pinned: pinned, expectedRevision: revision)
            guard revision == client.sessionRevision, !Task.isCancelled else { return }
            if let error = response.error { throw ServerError.badRequest(error) }
            pinSnapshot = response
            pinsLoaded = true
        } catch is CancellationError { return }
        catch {
            guard revision == client.sessionRevision else { return }
            pinError = error.localizedDescription
            failedPin = (slug, pinned)
        }
    }

    func retryPin() async {
        guard let failedPin else { return }
        await setPinned(slug: failedPin.slug, pinned: failedPin.pinned)
    }
}
