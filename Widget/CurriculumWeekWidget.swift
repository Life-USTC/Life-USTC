//
//  CurriculumWeekWidget.swift
//  Widget
//
//  Created by Ode on 2023/3/7.
//

import Intents
import SwiftUI
import WidgetKit

struct CurriculumWeekProvider: TimelineProvider {
    @ManagedData(.curriculum) var curriculum: Curriculum

    func placeholder(in _: Context) -> CurriculumWeekEntry {
        CurriculumWeekEntry.example
    }

    func makeEntry(for _date: Date = Date()) async throws -> CurriculumWeekEntry {
        let date = _date.startOfWeek()
        let curriculum = try await _curriculum.retrive()!
        let currentSemester: Semester? =
            curriculum.semesters
            .filter { ($0.startDate ... $0.endDate).contains(date) }
            .first

        let lectures: [Lecture] =
            (currentSemester == nil
            ? curriculum.semesters.flatMap { $0.courses.flatMap(\.lectures) }
            : currentSemester!.courses.flatMap(\.lectures))
            .filter {
                (0.0 ..< 3600.0 * 24 * 7)
                    .contains($0.startDate.stripTime().timeIntervalSince(date))
            }

        var weekNumber: Int? = nil

        if let currentSemester {
            weekNumber =
                (Calendar(identifier: .gregorian)
                    .dateComponents(
                        [.weekOfYear],
                        from: currentSemester.startDate,
                        to: date
                    )
                    .weekOfYear ?? 0) + 1
        } else {
            weekNumber = nil
        }

        return .init(
            lectures: lectures,
            date: date,
            currentSemesterName: currentSemester?.name ?? "All",
            weekNumber: weekNumber
        )
    }

    func getSnapshot(
        in _: Context,
        completion: @escaping (CurriculumWeekEntry) -> Void
    ) {
        Task {
            let date = Date()
            let entry = try await makeEntry(for: date)
            completion(entry)
        }
    }

    func getTimeline(
        in _: Context,
        completion: @escaping (Timeline<Entry>) -> Void
    ) {
        Task {
            let date = Date()
            let entry = try await makeEntry(for: date)

            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
}

struct CurriculumWeekEntry: TimelineEntry {
    var lectures: [Lecture]
    var date: Date
    var currentSemesterName: String
    var weekNumber: Int?

    static let example = CurriculumWeekEntry(
        lectures: [.example],
        date: .now,
        currentSemesterName: Semester.example.name,
        weekNumber: nil
    )
}

struct CurriculumWeekWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: CurriculumWeekProvider.Entry

    var body: some View {
        CurriculumWeekView(
            lectures: entry.lectures,
            _date: entry.date,
            currentSemesterName: entry.currentSemesterName,
            weekNumber: entry.weekNumber,
            fontSize: widgetFamily == .systemExtraLarge ? 15 : 10
        )
        .padding(3)
        .widgetBackground(
            Color.clear
        )
    }
}

struct CurriculumWeekWidget: Widget {
    let kind: String = "CurriculumWeekWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurriculumWeekProvider()) {
            CurriculumWeekWidgetEntryView(entry: $0)
        }
        .supportedFamilies([.systemExtraLarge])
        .configurationDisplayName("Curriculum")
        .description("Show this week's curriculum")
    }
}

struct CurriculumWeekWidget_Previews: PreviewProvider {
    static var previews: some View {
        CurriculumWeekWidgetEntryView(entry: .example)
            .previewContext(WidgetPreviewContext(family: .systemExtraLarge))
    }
}
