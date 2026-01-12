//
//  CurriculumPreviewWidget.swift
//  Widget
//
//  Created by Tiankai Ma on 2023/8/26.
//

import Intents
import SwiftData
import SwiftUI
import WidgetKit

struct CurriculumProvider: TimelineProvider {
    func makeEntry(for _date: Date = Date()) -> CurriculumEntry {
        return CurriculumEntry()
    }

    func placeholder(in _: Context) -> CurriculumEntry {
        return makeEntry()
    }

    func getSnapshot(
        in _: Context,
        completion: @escaping (CurriculumEntry) -> Void
    ) {
        Task {
            let entry = makeEntry()
            completion(entry)
        }
    }

    func getTimeline(
        in _: Context,
        completion: @escaping (Timeline<Entry>) -> Void
    ) {
        Task {
            let entry = makeEntry()

            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
}

struct CurriculumEntry: TimelineEntry {
    let date: Date = Date()
}

struct CurriculumWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: CurriculumProvider.Entry

    static var referenceDate: Date { Date() }
    static var todayStart: Date { referenceDate.stripTime() }
    static var tomorrowStart: Date { todayStart.add(day: 1) }
    static var dayAfterTomorrowStart: Date { todayStart.add(day: 2) }

    @Query(
        filter: #Predicate<Lecture> { lecture in
            todayStart <= lecture.startDate && lecture.startDate < tomorrowStart
        },
        sort: [SortDescriptor(\Lecture.startDate, order: .forward)]
    ) var _todayLectures: [Lecture]

    var todayLectures: [Lecture] {
        _todayLectures.staged()
    }

    @Query(
        filter: #Predicate<Lecture> { lecture in
            tomorrowStart <= lecture.startDate && lecture.startDate < dayAfterTomorrowStart
        },
        sort: [SortDescriptor(\Lecture.startDate, order: .forward)]
    ) var _tomorrowLectures: [Lecture]

    var tomorrowLectures: [Lecture] {
        _tomorrowLectures.staged()
    }

    var body: some View {
        VStack {
            if widgetFamily == .systemLarge {
                CurriculumListWidget(
                    lectures: todayLectures,
                    numberToShow: 4
                )
            } else if widgetFamily == .systemMedium {
                CurriculumListWidget(
                    lectures: todayLectures,
                    numberToShow: 2
                )
            }
        }
        .padding(3)
        .widgetBackground(
            Color.clear
        )
    }
}

struct CurriculumWidget: Widget {
    let kind: String = "CurriculumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: CurriculumProvider()
        ) {
            CurriculumWidgetEntryView(entry: $0)
                .modelContainer(SwiftDataStack.modelContainer)
        }
        .supportedFamilies([
            .systemMedium,
            .systemLarge,
        ])
        .configurationDisplayName("Curriculum")
        .description("Show today & tomorrow's lectures")
    }
}
