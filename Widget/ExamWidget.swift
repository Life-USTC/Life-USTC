//
//  ExamWidget.swift
//  ExamWidget
//
//  Created by TiankaiMa on 2023/1/22.
//

import Intents
import SwiftData
import SwiftUI
import WidgetKit

struct ExamProvider: TimelineProvider {
    func makeEntry(for _date: Date = Date()) -> ExamEntry {
        return ExamEntry()
    }

    func placeholder(in _: Context) -> ExamEntry {
        return makeEntry()
    }

    func getSnapshot(in _: Context, completion: @escaping (ExamEntry) -> Void) {
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

struct ExamEntry: TimelineEntry {
    let date = Date()
    @Query var exams: [Exam]
}

struct ExamWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: ExamProvider.Entry

    var body: some View {
        VStack {
            if widgetFamily == .systemMedium {
                ExamPreview
                    .makeListWidget(
                        with: entry.exams,
                        numberToShow: 2
                    )
            } else if widgetFamily == .systemLarge {
                ExamPreview
                    .makeListWidget(
                        with: entry.exams,
                        numberToShow: 6
                    )
            } else if widgetFamily == .systemSmall {
                ExamPreview
                    .makeDayWidget(
                        with: entry.exams.filter { !$0.isFinished }.first
                    )
            }
        }
        .padding(3)
        .widgetBackground(
            Color.clear
        )
    }
}

struct ExamWidget: Widget {
    let kind: String = "ExamWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ExamProvider()) { entry in
            ExamWidgetEntryView(entry: entry)
        }
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
        ])
        .configurationDisplayName("Exams")
        .description("Show upcoming exam")
    }
}
