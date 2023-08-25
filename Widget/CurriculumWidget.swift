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

    func fetchLectures(for _date: Date = Date()) async throws -> [Lecture] {
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

        return lectures
    }

    func getSnapshot(
        in _: Context,
        completion: @escaping (CurriculumEntry) -> Void
    ) {
        Task {
            let date = Date().add(day: 21)
            let lectures = try await fetchLectures(for: date)
            let entry = CurriculumEntry(date: date, lectures: lectures)
            completion(entry)
        }
    }

    func getTimeline(
        in _: Context,
        completion: @escaping (Timeline<Entry>) -> Void
    ) {
        Task {
            let date = Date().add(day: 21)
            let lectures = try await fetchLectures(for: date)
            let entry = CurriculumEntry(date: date, lectures: lectures)

            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
}

struct CurriculumEntry: TimelineEntry {
    var date: Date = .now
    var lectures: [Lecture]

    static let example = CurriculumEntry(lectures: [.example])
}

struct CurriculumWidgetEntryView: View {
    var entry: CurriculumProvider.Entry

    var body: some View {
        CurriculumWeekView(
            lectures: .constant(entry.lectures),
            _date: .constant(entry.date)
        )
        .widgetBackground(Color.black)
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
