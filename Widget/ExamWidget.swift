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
}

struct ExamWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: ExamProvider.Entry

    @Query(sort: \Exam.startDate, order: .forward) var _exams: [Exam]

    var exams: [Exam] {
        _exams.staged(showFinishedExams: false)
    }

    var body: some View {
        VStack {
            if widgetFamily == .systemMedium {
                ExamListWidget(
                    exams: exams,
                    numberToShow: 2
                )
            } else if widgetFamily == .systemLarge {
                ExamListWidget(
                    exams: exams,
                    numberToShow: 6
                )
            } else if widgetFamily == .systemSmall {
                ExamDayWidget(
                    exam: exams.first
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
                .modelContainer(SwiftDataStack.modelContainer)
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
