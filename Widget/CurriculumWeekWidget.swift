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

@MainActor
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
    var todayStart: Date { referenceDate.stripTime() }
    var weekStart: Date { todayStart.startOfWeek() }
    var weekEnd: Date { weekStart.add(day: 7) }

    @Query(sort: \Lecture.startDate, order: .forward) var lecturesQuery: [Lecture]

    var lectures: [Lecture] {
        lecturesQuery
            .filter {
                (weekStart ... weekEnd)
                    .contains($0.startDate.stripTime())
            }
    }

    var body: some View {
        CurriculumChartView(
            lectures: lectures,
            referenceDate: referenceDate,
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
