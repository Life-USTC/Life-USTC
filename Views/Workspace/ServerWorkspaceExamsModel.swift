import SwiftUI

extension ServerWorkspaceExam {
    func isPast(at date: Date) -> Bool {
        guard let examDate else { return false }
        let examDay = YoungCalendarDate.dayStart(examDate)
        let today = YoungCalendarDate.dayStart(date)
        if examDay != today { return examDay < today }
        guard let endTime,
              let end = YoungCalendarDate.calendar.date(bySettingHour: endTime / 100,
                                                        minute: endTime % 100, second: 0, of: examDay)
        else { return false }
        return end <= date
    }
}

@Observable
@MainActor
final class ServerWorkspaceExamsModel {
    var semesterID: Int?
    private(set) var isLoading = false
    private(set) var error: String?

    private let client: ServerClient
    private var snapshot: [ServerWorkspaceExam] = []
    private var loadedRevision: UUID?
    private var generation = 0

    init(client: ServerClient = .shared) { self.client = client }

    var exams: [ServerWorkspaceExam] {
        guard ownsSnapshot else { return [] }
        return snapshot.filter { semesterID == nil || $0.section.semesterId == semesterID }
    }

    var semesters: [ServerSemester] {
        guard ownsSnapshot else { return [] }
        var seen: Set<Int> = []
        return snapshot.compactMap(\.section.semester)
            .filter { seen.insert($0.id).inserted }
            .sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
    }

    func exam(id: Int) -> ServerWorkspaceExam? {
        ownsSnapshot ? snapshot.first { $0.id == id } : nil
    }

    private var ownsSnapshot: Bool {
        client.isAuthenticated && loadedRevision == client.sessionRevision
    }

    func load() async {
        generation += 1
        let requestGeneration = generation
        let revision = client.sessionRevision
        resetForSessionIfNeeded()
        error = nil
        isLoading = client.isAuthenticated
        guard client.isAuthenticated else { return }
        defer {
            if requestGeneration == generation {
                isLoading = false
                resetForSessionIfNeeded()
            }
        }
        do {
            let locale = Locale.current.language.languageCode?.identifier == "en" ? "en-us" : "zh-cn"
            let loaded = try await client.fetchAllSubscribedExams(filters: .init(locale: locale))
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            snapshot = loaded
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }

    private func resetForSessionIfNeeded() {
        guard loadedRevision != client.sessionRevision || !client.isAuthenticated else { return }
        loadedRevision = client.sessionRevision
        snapshot = []
        semesterID = nil
        error = nil
    }
}
