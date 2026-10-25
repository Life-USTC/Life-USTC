import SwiftUI

struct ServerPublicScheduleFilters: Equatable {
    var sectionCode = ""
    var teacherCode = ""
    var roomJWID = ""
    var weekday: Int?
    var limitsDates = false
    var dateFrom = YoungCalendarDate.dayStart(.now)
    var dateTo = YoungCalendarDate.dayStart(.now)

    var validationError: String? {
        let room = roomJWID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !room.isEmpty && (Int(room) ?? 0) <= 0 {
            return String(localized: "Enter a valid university room ID.")
        }
        if limitsDates && YoungCalendarDate.dayStart(dateFrom) > YoungCalendarDate.dayStart(dateTo) {
            return String(localized: "The end date must be on or after the start date.")
        }
        return nil
    }

    fileprivate var normalized: Self {
        var filters = self
        filters.sectionCode = sectionCode.trimmingCharacters(in: .whitespacesAndNewlines)
        filters.teacherCode = teacherCode.trimmingCharacters(in: .whitespacesAndNewlines)
        filters.roomJWID = roomJWID.trimmingCharacters(in: .whitespacesAndNewlines)
        return filters
    }
}

@Observable
@MainActor
final class ServerPublicScheduleModel {
    private(set) var filters = ServerPublicScheduleFilters()
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var total = 0
    private(set) var hasMore = false
    private(set) var reachedPageLimit = false

    private let client: ServerClient
    private var snapshot: [ServerScheduleEntry] = []
    private var loadedRevision: UUID?
    private var page = 0
    private var generation = 0

    init(client: ServerClient = .shared) { self.client = client }

    var schedules: [ServerScheduleEntry] {
        loadedRevision == client.sessionRevision ? snapshot : []
    }

    func apply(_ filters: ServerPublicScheduleFilters, locale: String) async {
        guard filters.validationError == nil else { return }
        self.filters = filters.normalized
        await load(locale: locale)
    }

    func load(append: Bool = false, locale: String) async {
        if append && (isLoading || !hasMore || loadedRevision != client.sessionRevision) { return }
        generation += 1
        let requestGeneration = generation
        let revision = client.sessionRevision
        let filters = filters
        let nextPage = append ? page + 1 : 1
        if !append {
            snapshot = []
            total = 0
            hasMore = false
            reachedPageLimit = false
            page = 0
            loadedRevision = revision
        }
        isLoading = true
        error = nil
        defer { if requestGeneration == generation { isLoading = false } }
        do {
            let response = try await client.querySchedules(
                dateFrom: filters.limitsDates ? YoungCalendarDate.dateString(filters.dateFrom) : nil,
                dateTo: filters.limitsDates ? YoungCalendarDate.dateString(filters.dateTo) : nil,
                weekday: filters.weekday,
                sectionCode: filters.sectionCode.isEmpty ? nil : filters.sectionCode,
                teacherCode: filters.teacherCode.isEmpty ? nil : filters.teacherCode,
                roomJwId: Int(filters.roomJWID), page: nextPage, pageSize: 30, locale: locale
            )
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            guard response.pagination.page == nextPage else {
                throw ServerError.serverError("The server returned an unexpected schedule page.".localized)
            }
            snapshot = append ? snapshot + response.data : response.data
            page = response.pagination.page
            total = response.pagination.total
            hasMore = page < response.pagination.totalPages && page < 100
            reachedPageLimit = page == 100 && page < response.pagination.totalPages
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}
