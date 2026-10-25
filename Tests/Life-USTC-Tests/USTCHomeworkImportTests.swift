import Foundation
import SwiftData
import XCTest
@testable import Life_USTC

final class USTCHomeworkImportTests: XCTestCase {
    @MainActor
    func testSharedCalendarImportReplacesOldHomeworkAndPersistsOriginalThreeFields() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let (container, context) = try makeStore()
        context.insert(Homework(title: "Old homework", courseName: "Old course", dueDate: .distantPast))
        try context.save()
        MockURLProtocol.stubData(Data(#"[{"id":"ignored","title":" 作业 1 ","endDate":"2026-03-15T23:59:59.123Z","calendarNameLocalizable":{"rawValue":" 线性代数 "},"calendarName":"not selected","end":"not selected","eventType":"graded"}]"#.utf8))

        let events = try await USTCBlackboardService(session: MockURLProtocol.mockSession()).fetchCalendarEvents()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Homework>()), 1)
        try USTCSchool.replaceHomework(with: events, in: context)

        let reader = ModelContext(container)
        let saved = try reader.fetch(FetchDescriptor<Homework>())
        XCTAssertEqual(saved.count, 1)
        let homework = try XCTUnwrap(saved.first)
        XCTAssertEqual(homework.title, " 作业 1 ")
        XCTAssertEqual(homework.courseName, " 线性代数 ")
        XCTAssertEqual(homework.dueDate.timeIntervalSince1970, 1773619199.123, accuracy: 0.0001)
        XCTAssertFalse(context.hasChanges)
    }

    @MainActor
    func testSharedCalendarImportSkipsInvalidDatesAndKeepsLastDueDatePerTitleAndCourse() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let (container, context) = try makeStore()
        MockURLProtocol.stubData(Data(#"[{"title":"Repeated","endDate":"2026-03-01T00:00:00.000Z","calendarNameLocalizable":{"rawValue":"Math"}},{"title":"Invalid date","endDate":"not a date","calendarNameLocalizable":{"rawValue":"Math"}},{"title":"Repeated","endDate":"2026-03-02T00:00:00.500Z","calendarNameLocalizable":{"rawValue":"Math"}},{"title":"Repeated","endDate":"2026-03-03T00:00:00.000Z","calendarNameLocalizable":{"rawValue":"Physics"}},{"title":"Repeated","endDate":"invalid last date","calendarNameLocalizable":{"rawValue":"Math"}},{"title":"CLI fallback","end":"2026-03-04T00:00:00Z","calendarName":"Math"}]"#.utf8))

        let events = try await USTCBlackboardService(session: MockURLProtocol.mockSession()).fetchCalendarEvents()
        XCTAssertEqual(events.count, 6)
        try USTCSchool.replaceHomework(with: events, in: context)

        let reader = ModelContext(container)
        let saved = try reader.fetch(FetchDescriptor<Homework>())
        XCTAssertEqual(saved.count, 2)
        let math = try XCTUnwrap(saved.first { $0.courseName == "Math" })
        XCTAssertEqual(math.title, "Repeated")
        XCTAssertEqual(math.dueDate.timeIntervalSince1970, 1772409600.5, accuracy: 0.0001)
        let physics = try XCTUnwrap(saved.first { $0.courseName == "Physics" })
        XCTAssertEqual(physics.title, "Repeated")
        XCTAssertEqual(physics.dueDate.timeIntervalSince1970, 1772496000, accuracy: 0.0001)
        XCTAssertFalse(context.hasChanges)
    }

    @MainActor
    private func makeStore() throws -> (ModelContainer, ModelContext) {
        let schema = Schema([Homework.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return (container, context)
    }
}
