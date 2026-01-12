//
//  CurriculumNextWidget.swift
//  Widget
//
//  Created by Tiankai Ma on 2026/1/12.
//

import SwiftData
import SwiftUI
import WidgetKit

struct CurriculumNextProvider: TimelineProvider {
    func makeEntry(for _date: Date = Date()) -> CurriculumNextEntry {
        return CurriculumNextEntry()
    }

    func placeholder(in _: Context) -> CurriculumNextEntry {
        return makeEntry()
    }

    func getSnapshot(
        in _: Context,
        completion: @escaping (CurriculumNextEntry) -> Void
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

struct CurriculumNextEntry: TimelineEntry {
    let date: Date = Date()
}

struct CurriculumNextWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: CurriculumNextProvider.Entry

    @Query(
        sort: [SortDescriptor(\Lecture.startDate, order: .forward)]
    ) var _lectures: [Lecture]

    var lecture: Lecture? {
        _lectures.filter { $0.endDate >= Date() }.first
    }

    var body: some View {
        VStack {
            CurriculumDayWidget(lecture: lecture)
        }
        .padding(3)
        .widgetBackground(Color.clear)
    }
}

struct CurriculumNextWidget: Widget {
    let kind: String = "CurriculumNextWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: CurriculumNextProvider()
        ) {
            CurriculumNextWidgetEntryView(entry: $0)
                .modelContainer(SwiftDataStack.modelContainer)
        }
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
        ])
        .configurationDisplayName(LocalizedStringKey("Next Lecture"))
        .description(LocalizedStringKey("Show the next upcoming lecture"))
    }
}
