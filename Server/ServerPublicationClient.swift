import Foundation

extension ServerClient {
    func fetchPublications(
        filters: ServerPublicationFilters = .init(), page: Int = 1, pageSize: Int = 20
    ) async throws -> PaginatedResponse<ServerPublicationListItem> {
        guard (1...100_000).contains(page), (1...50).contains(pageSize) else {
            throw ServerError.badRequest(String(localized: "Invalid publication page."))
        }
        guard Set(filters.sources).count <= 20 else {
            throw ServerError.badRequest(String(localized: "Select up to 20 publication sources."))
        }
        guard filters.query.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count <= 200 else {
            throw ServerError.badRequest(String(localized: "Search must be 200 characters or fewer."))
        }
        return try await request(.listPublications(filters: filters, page: page, pageSize: pageSize))
    }

    func fetchPublication(id: String) async throws -> ServerPublicationDetail {
        try await request(.getPublication(id: id))
    }

    func fetchPublicationSources() async throws -> ServerPublicationSourceDirectory {
        try await request(.listPublicationSources)
    }
}
