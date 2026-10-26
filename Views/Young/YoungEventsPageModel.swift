import Foundation
import Observation
import LifeClientCore

@MainActor
@Observable
final class YoungEventsPageModel {
    private let client: ServerClient
    private var query: YoungEventQuery = .init()
    private var progress = PageProgress(firstPage: 1)
    private var totalPages = 1
    private var generation = 0

    var events: [ServerYoungEvent] = []
    var unknownDateCount = 0
    var source: ServerYoungCatalogSource?
    var isLoading = false
    var error: String?
    var isComplete: Bool { progress.nextPage == 0 }

    init(client: ServerClient = .shared) {
        self.client = client
    }

    func load(_ query: YoungEventQuery) async {
        generation += 1
        self.query = query
        progress = PageProgress(firstPage: 1)
        totalPages = 1
        events = []
        unknownDateCount = 0
        source = nil
        await loadRemaining(generation: generation)
    }

    func continueLoading() async {
        guard !isLoading, !isComplete else { return }
        await loadRemaining(generation: generation)
    }

    private func loadRemaining(generation requestGeneration: Int) async {
        isLoading = true
        error = nil
        defer {
            if requestGeneration == generation { isLoading = false }
        }
        do {
            while !isComplete {
                let requestedPage = progress.nextPage
                let page = try await client.fetchYoungEventsBatch(query, page: requestedPage)
                guard requestGeneration == generation, !Task.isCancelled else { return }
                if requestedPage == 1 {
                    totalPages = page.pagination.totalPages
                    unknownDateCount = page.unknownDateCount
                    source = page.source
                }
                events.append(contentsOf: page.data)
                progress = progress.afterPage(itemCount: page.data.count, hasMore: requestedPage < totalPages)
            }
        } catch {
            guard requestGeneration == generation, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}
