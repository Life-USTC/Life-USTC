import SwiftUI

@Observable
@MainActor
final class ServerPublicationsModel {
    var filters: ServerPublicationFilters
    private let client: ServerClient
    private var snapshot: [ServerPublicationListItem] = []
    private var snapshotFilters: ServerPublicationFilters?
    private var snapshotPagination: PaginationInfo?
    private var loadingFilters: ServerPublicationFilters?
    private var failedFilters: ServerPublicationFilters?
    private var failedPage: Int?
    private var loadingError: String?

    init(filters: ServerPublicationFilters = .init(), client: ServerClient = .shared) {
        self.filters = filters
        self.client = client
    }

    var publications: [ServerPublicationListItem] { snapshotFilters == filters ? snapshot : [] }
    var pagination: PaginationInfo? { snapshotFilters == filters ? snapshotPagination : nil }
    var isLoading: Bool { loadingFilters == filters }
    var error: String? { failedFilters == filters ? loadingError : nil }
    var hasMore: Bool { pagination.map { $0.page < $0.totalPages } ?? false }

    func load() async { await load(page: 1) }

    func loadMore() async {
        guard !isLoading, hasMore, let pagination else { return }
        await load(page: pagination.page + 1)
    }

    func retry() async {
        guard !isLoading else { return }
        await load(page: failedFilters == filters ? failedPage ?? 1 : 1)
    }

    private func load(page: Int) async {
        let requestedFilters = filters
        loadingFilters = requestedFilters
        failedFilters = nil
        failedPage = nil
        loadingError = nil
        defer { if loadingFilters == requestedFilters { loadingFilters = nil } }
        do {
            let response = try await client.fetchPublications(filters: requestedFilters, page: page)
            guard !Task.isCancelled, requestedFilters == filters else { return }
            if page == 1 { snapshot = response.data }
            else { snapshot.append(contentsOf: response.data) }
            snapshotFilters = requestedFilters
            snapshotPagination = response.pagination
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, requestedFilters == filters else { return }
            failedFilters = requestedFilters
            failedPage = page
            loadingError = error.localizedDescription
        }
    }
}

@Observable
@MainActor
final class ServerPublicationDetailModel {
    let id: String
    private let client: ServerClient
    private(set) var publication: ServerPublicationDetail?
    private(set) var isLoading = false
    private(set) var error: String?

    init(id: String, client: ServerClient = .shared) {
        self.id = id
        self.client = client
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let result = try await client.fetchPublication(id: id)
            guard !Task.isCancelled else { return }
            publication = result
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}

@Observable
@MainActor
final class ServerPublicationSourcesModel {
    private let client: ServerClient
    private(set) var directory: ServerPublicationSourceDirectory?
    private(set) var isLoading = false
    private(set) var error: String?

    init(client: ServerClient = .shared) { self.client = client }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let result = try await client.fetchPublicationSources()
            guard !Task.isCancelled else { return }
            directory = result
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}
