//
//  CurriculumPreviewWidget.swift
//  Widget
//
//  Created by Tiankai Ma on 2023/8/26.
//

import Intents
import SwiftUI
import WidgetKit

struct CurriculumPreviewProvider: TimelineProvider {
    @ManagedData(.curriculum) var curriculum: Curriculum

    func placeholder(in _: Context) -> CurriculumPreviewEntry {
        CurriculumPreviewEntry.example
    }

    func makeEntry(for date: Date = Date()) async throws
        -> CurriculumPreviewEntry
    {
        let curriculum = try await _curriculum.retrive()!

        let todayLectures =
            curriculum.semesters.flatMap(\.courses).flatMap(\.lectures)
            .filter {
                (date ..< date.add(day: 1)).contains($0.startDate)
            }
            .sort()

        let tomorrowLectures =
            curriculum.semesters.flatMap(\.courses).flatMap(\.lectures)
            .filter {
                (date.add(day: 1) ..< date.add(day: 2)).contains($0.startDate)
            }
            .sort()

        return .init(
            date: date,
            todayLectures: todayLectures,
            tomorrowLectures: tomorrowLectures
        )
    }

    func getSnapshot(
        in _: Context,
        completion: @escaping (CurriculumPreviewEntry) -> Void
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

struct CurriculumPreviewEntry: TimelineEntry {
    var date: Date
    var todayLectures: [Lecture]
    var tomorrowLectures: [Lecture]

    static let example = CurriculumPreviewEntry(
        date: .now,
        todayLectures: [.example],
        tomorrowLectures: [.example, .example, .example]
    )
}

struct CurriculumPreviewWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: CurriculumPreviewProvider.Entry

    var body: some View {
        if widgetFamily == .systemLarge
            || (widgetFamily == .systemMedium
                && entry.todayLectures.count <= 2
                && entry.tomorrowLectures.count <= 2)
        {
            CurriculumTodayView(
                lectureListA: Array(entry.todayLectures.prefix(6)),
                lectureListB: Array(entry.tomorrowLectures.prefix(6))
            )
        } else if widgetFamily == .systemMedium {
            CurriculumTodayView(
                lectureListA: Array(entry.todayLectures.prefix(2)),
                lectureListB: Array(
                    entry.todayLectures.dropFirst(2).prefix(2)
                ),
                listAText: "Today",
                listBText: nil
            )
        } else if widgetFamily == .systemSmall {
            CurriculumTodayView()
                .makeWidget(
                    with: entry.todayLectures.first,
                    text: "Today"
                )
        }
    }
}

struct CurriculumPreviewWidget: Widget {
    let kind: String = "CurriculumPreviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: CurriculumPreviewProvider()
        ) {
            CurriculumPreviewWidgetEntryView(entry: $0)
        }
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
        ])
        .configurationDisplayName("Curriculum")
        .description("Show today & tomorrow's lectures")
    }
}

struct CurriculumPreviewWidget_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(WidgetFamily.allCases, id: \.rawValue) { family in
            CurriculumPreviewWidgetEntryView(entry: .example)
                .previewContext(WidgetPreviewContext(family: family))
                .previewDisplayName(family.description)
        }
    }
}
