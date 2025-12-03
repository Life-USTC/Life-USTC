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

struct CurriculumPreviewWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: CurriculumPreviewProvider.Entry

    @Query var todayLectures: [Lecture]
    @Query var tomorrowLectures: [Lecture]

    var body: some View {
        VStack {
            if widgetFamily == .systemLarge {
                CurriculumPreview
                    .makeListWidget(
                        with: todayLectures,
                        numberToShow: 4
                    )
            } else if widgetFamily == .systemMedium {
                CurriculumPreview
                    .makeListWidget(
                        with: todayLectures,
                        numberToShow: 2
                    )
            } else if widgetFamily == .systemSmall {
                CurriculumPreview
                    .makeDayWidget(
                        with: todayLectures.first
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
