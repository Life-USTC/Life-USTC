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

struct CurriculumPreviewProvider: TimelineProvider {
    func makeEntry(for _date: Date = Date()) -> CurriculumPreviewEntry {
        return CurriculumPreviewEntry()
    }

    func placeholder(in _: Context) -> CurriculumPreviewEntry {
        return makeEntry()
    }

    func getSnapshot(
        in _: Context,
        completion: @escaping (CurriculumPreviewEntry) -> Void
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

struct CurriculumPreviewEntry: TimelineEntry {
    let date: Date = Date()
}

extension [Lecture] {
    fileprivate func reorderForWidget() -> [Lecture] {
        return
            self.filter {
                !$0.isFinished
            }
            + self.filter {
                $0.isFinished
            }
    }
}

struct CurriculumPreviewWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: CurriculumPreviewProvider.Entry

    static var referenceDate: Date { Date() }
    static var todayStart: Date { referenceDate.stripTime() }
    static var tomorrowStart: Date { todayStart.add(day: 1) }
    static var dayAfterTomorrowStart: Date { todayStart.add(day: 2) }

    @Query(
        filter: #Predicate<Lecture> { lecture in
            todayStart <= lecture.startDate && lecture.startDate < tomorrowStart
        },
        sort: [SortDescriptor(\Lecture.startDate, order: .forward)]
    ) var todayLectures: [Lecture]

    @Query(
        filter: #Predicate<Lecture> { lecture in
            tomorrowStart <= lecture.startDate && lecture.startDate < dayAfterTomorrowStart
        },
        sort: [SortDescriptor(\Lecture.startDate, order: .forward)]
    ) var tomorrowLectures: [Lecture]

    var body: some View {
        VStack {
            if widgetFamily == .systemLarge {
                CurriculumListWidget(
                    lectures: todayLectures,
                    numberToShow: 4
                )
            } else if widgetFamily == .systemMedium {
                CurriculumListWidget(
                    lectures: todayLectures.reorderForWidget(),
                    numberToShow: 2
                )
            } else if widgetFamily == .systemSmall {
                CurriculumDayWidget(
                    lecture: todayLectures.reorderForWidget().first
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
                .modelContainer(SwiftDataStack.modelContainer)
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
