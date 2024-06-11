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
    @AppStorage("widgetCanRefreshNewData", store: .appGroup) var _widgetCanRefreshNewData: Bool? = nil
    var canRefresh: Bool {
        _widgetCanRefreshNewData ?? false
    }

    func placeholder(in _: Context) -> CurriculumPreviewEntry {
        CurriculumPreviewEntry.example
    }

    func makeEntry(for _date: Date = Date()) async throws
        -> CurriculumPreviewEntry
    {
        let date = _date.stripTime()
        guard let curriculum = try await canRefresh ? _curriculum.retrive() : _curriculum.retriveLocal() else {
            throw BaseError.runtimeError("Failed to retrive curriculum data")
        }

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
            todayLectures: todayLectures.clean(),
            tomorrowLectures: tomorrowLectures.clean()
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
        VStack {
            if widgetFamily == .systemLarge {
                CurriculumTodayView()
                    .makeListWidget(
                        with: entry.todayLectures,
                        numberToShow: 4
                    )
            } else if widgetFamily == .systemMedium {
                CurriculumTodayView()
                    .makeListWidget(
                        with: entry.todayLectures,
                        numberToShow: 2
                    )
            } else if widgetFamily == .systemSmall {
                CurriculumTodayView()
                    .makeWidget(
                        with: entry.todayLectures.first
                    )
            }
        }
        .padding(3)
        .widgetBackground(
            Color("BackgroundWhite")
        )
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
