import SwiftUI

@Observable
@MainActor
final class ServerWorkspaceCalendarModel {
    var mode: WorkspaceCalendarMode = .week
    var selectedSemesterID: Int?
    private var semesterSnapshot: [ServerSemester] = []
    private var semesterRevision: UUID?
    private(set) var semesterError: String?
    var referenceDate = Date()
    var rangeOverride: ServerCalendarRange?
    private var snapshot: [ServerPersonalCalendarEvent] = []
    private(set) var isLoading = false
    private(set) var error: String?

    private let client: ServerClient
    private var generation = 0
    private var loadedRequest: String?

    init(client: ServerClient = .shared) { self.client = client }

    var requestID: String {
        if let rangeOverride {
            return "\(YoungCalendarDate.dateString(rangeOverride.start))/\(YoungCalendarDate.dateString(rangeOverride.end))"
        }
        return "\(mode.rawValue)-\(YoungCalendarDate.dateString(referenceDate))-\(mode == .semester ? String(selectedSemesterID ?? 0) : "")"
    }

    private var snapshotKey: String { "\(client.sessionRevision)-\(requestID)" }

    var events: [ServerPersonalCalendarEvent] {
        client.isAuthenticated && loadedRequest == snapshotKey ? snapshot : []
    }

    var semesters: [ServerSemester] {
        client.isAuthenticated && semesterRevision == client.sessionRevision ? semesterSnapshot : []
    }

    var selectedSemester: ServerSemester? { semesters.first { $0.id == selectedSemesterID } }
    var modes: [WorkspaceCalendarMode] { semesters.isEmpty ? [.day, .week, .month] : WorkspaceCalendarMode.allCases }

    var range: ServerCalendarRange? {
        if let rangeOverride { return rangeOverride }
        if mode == .semester {
            guard let semester = selectedSemester, let start = semester.startDate, let end = semester.endDate else { return nil }
            return ServerCalendarRange(start: start, end: end)
        }
        let shortMode = YoungCalendarDisplayMode(rawValue: mode.rawValue)!
        let value = YoungCalendarDate.range(for: shortMode, date: referenceDate)
        return ServerCalendarRange(start: YoungCalendarDate.dateFormatter.date(from: value.from)!,
                                   end: YoungCalendarDate.dateFormatter.date(from: value.to)!)
    }

    var agendaDays: [WorkspaceCalendarDay] {
        guard let range else { return [] }
        if mode == .week || mode == .day {
            return range.days.map { day in
                let next = YoungCalendarDate.calendar.date(byAdding: .day, value: 1, to: day)!
                return WorkspaceCalendarDay(date: day, events: events.filter { event in
                    guard let at = event.at else { return false }
                    return at < next && (at >= day || (event.endsAt ?? at) > day)
                })
            }
        }
        let groups = Dictionary(grouping: events.filter { $0.at != nil }) {
            max(YoungCalendarDate.dayStart($0.at!), range.start)
        }
        return groups.keys.sorted().map { WorkspaceCalendarDay(date: $0, events: groups[$0]!) }
    }

    func navigate(_ amount: Int) {
        if mode == .semester {
            guard let index = semesters.firstIndex(where: { $0.id == selectedSemesterID }),
                  semesters.indices.contains(index - amount) else { return }
            selectedSemesterID = semesters[index - amount].id
        } else {
            referenceDate = YoungCalendarDate.advance(referenceDate,
                mode: YoungCalendarDisplayMode(rawValue: mode.rawValue)!, amount: amount)
        }
    }

    func selectToday(_ today: Date = Date()) {
        referenceDate = today
        if mode == .semester {
            selectedSemesterID = semesters.first {
                guard let start = $0.startDate, let end = $0.endDate else { return false }
                return start <= today && YoungCalendarDate.dayStart(today) <= end
            }?.id
            if selectedSemesterID == nil { mode = .week }
        }
    }

    func loadSemesters() async {
        let revision = client.sessionRevision
        if semesterRevision != revision { semesterSnapshot = []; semesterRevision = revision }
        semesterError = nil
        guard client.isAuthenticated else { return }
        do {
            let subscriptions = try await client.fetchLearningSubscriptions()
            guard revision == client.sessionRevision, !Task.isCancelled else { return }
            var ids = Set<Int>()
            semesterSnapshot = subscriptions.compactMap(\.semester).filter {
                guard let start = $0.startDate, let end = $0.endDate, start <= end else { return false }
                return ids.insert($0.id).inserted
            }.sorted { $0.startDate! > $1.startDate! }
            if !semesters.contains(where: { $0.id == selectedSemesterID }) {
                selectedSemesterID = semesters.first {
                    $0.startDate! <= referenceDate && YoungCalendarDate.dayStart(referenceDate) <= $0.endDate!
                }?.id ?? semesters.first?.id
            }
            if semesters.isEmpty && mode == .semester { mode = .week }
        } catch {
            guard revision == client.sessionRevision, !Task.isCancelled else { return }
            semesterError = error.localizedDescription
        }
    }

    func load() async {
        generation += 1
        let requestGeneration = generation
        let revision = client.sessionRevision
        let key = snapshotKey
        if key != loadedRequest {
            snapshot = []
            loadedRequest = key
        }
        error = nil
        isLoading = client.isAuthenticated
        guard client.isAuthenticated else {
            snapshot = []
            return
        }
        guard let range else { isLoading = false; return }
        defer {
            if requestGeneration == generation {
                isLoading = false
                if revision != client.sessionRevision {
                    snapshot = []
                    loadedRequest = nil
                }
            }
        }
        do {
            var result: [ServerPersonalCalendarEvent] = []
            var ids = Set<String>()
            for window in range.requestWindows {
                let page = try await client.fetchPersonalCalendarEvents(dateFrom: window.from, dateTo: window.to)
                guard revision == client.sessionRevision, !Task.isCancelled else { return }
                result.append(contentsOf: page.filter { ids.insert($0.id).inserted })
            }
            result.sort { ($0.at ?? .distantFuture, $0.id) < ($1.at ?? .distantFuture, $1.id) }
            guard requestGeneration == generation, revision == client.sessionRevision,
                  key == snapshotKey, !Task.isCancelled else { return }
            snapshot = result
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision,
                  key == snapshotKey, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}
