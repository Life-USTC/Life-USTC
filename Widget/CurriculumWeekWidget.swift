//
//  CurriculumWeekWidget.swift
//  Widget
//
//  Created by Ode on 2023/3/7.
//

import Intents
import SwiftData
import SwiftUI
import WidgetKit

struct CurriculumWeekProvider: TimelineProvider {
    func makeEntry(for date: Date = Date()) -> CurriculumWeekEntry {
        return CurriculumWeekEntry()
    }

    func placeholder(in _: Context) -> CurriculumWeekEntry {
        makeEntry()
    }

    func getSnapshot(
        in _: Context,
        completion: @escaping (CurriculumWeekEntry) -> Void
    ) {
        Task {
            let date = Date()
            let entry = makeEntry(for: date)
            completion(entry)
        }
    }

    func getTimeline(
        in _: Context,
        completion: @escaping (Timeline<Entry>) -> Void
    ) {
        Task {
            let date = Date()
            let entry = makeEntry(for: date)

            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
}

struct CurriculumWeekEntry: TimelineEntry {
    var date: Date = Date()
}

struct CurriculumWeekWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: CurriculumWeekProvider.Entry

    @State var referenceDate: Date = Date()
    var todayStart: Date { ProductCalendar.dayStart(referenceDate) }
    var weekStart: Date { todayStart.startOfWeek() }
    var weekEnd: Date { ProductCalendar.weekRange(containing: referenceDate).upperBound }

    @Query(sort: \Lecture.startDate, order: .forward) var lecturesQuery: [Lecture]

    var lectures: [Lecture] {
        lecturesQuery
            .filter {
                ProductCalendar.weekRange(containing: referenceDate).contains($0.startDate)
            }
    }

    var body: some View {
        CurriculumChartView(
            lectures: lectures,
            referenceDate: referenceDate,
            behavior: .ustc,
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
                .modelContainer(SwiftDataStack.modelContainer)
        }
        .supportedFamilies([.systemExtraLarge])
        .configurationDisplayName("Curriculum")
        .description("Show this week's curriculum")
    }
}
