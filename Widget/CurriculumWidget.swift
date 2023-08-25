//
//  CurriculumWidget.swift
//  CurriculumWidget
//
//  Created by Ode on 2023/3/7.
//

import Intents
import SwiftUI
import WidgetKit

struct CurriculumProvider: TimelineProvider {
    @ManagedData(.curriculum) var curriculum: Curriculum

    func placeholder(in _: Context) -> CurriculumEntry {
        CurriculumEntry.example
    }

    func makeEntry(for _date: Date = Date()) async throws -> CurriculumEntry {
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
        completion: @escaping (CurriculumEntry) -> Void
    ) {
        Task {
            let date = Date().add(day: 21)
            let entry = try await makeEntry(for: date)
            completion(entry)
        }
    }

    func getTimeline(
        in _: Context,
        completion: @escaping (Timeline<Entry>) -> Void
    ) {
        Task {
            let date = Date().add(day: 21)
            let entry = try await makeEntry(for: date)

            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
}

struct CurriculumEntry: TimelineEntry {
    var lectures: [Lecture]
    var date: Date = .now
    var currentSemesterName: String
    var weekNumber: Int?

    static let example = CurriculumEntry(
        lectures: [.example],
        currentSemesterName: Semester.example.name
    )
}

struct CurriculumWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: CurriculumProvider.Entry

    var body: some View {
        CurriculumWeekView(
            lectures: entry.lectures,
            _date: entry.date,
            currentSemesterName: entry.currentSemesterName,
            weekNumber: entry.weekNumber,
            fontSize: widgetFamily == .systemExtraLarge ? 15 : 10
        )
        .widgetBackground(
            Color.clear
        )
    }
}

struct CurriculumWidget: Widget {
    let kind: String = "CurriculumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurriculumProvider()) {
            CurriculumWidgetEntryView(entry: $0)
        }
        .supportedFamilies([.systemLarge, .systemExtraLarge])
        .configurationDisplayName("Curriculum")
        .description("Show today's curriculum.")
    }
}

struct CurriculumWidget_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(WidgetFamily.allCases, id: \.rawValue) { family in
            CurriculumWidgetEntryView(entry: .example)
                .previewContext(WidgetPreviewContext(family: family))
                .previewDisplayName(family.description)
        }
    }
}
