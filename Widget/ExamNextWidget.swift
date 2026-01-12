//
//  ExamNextWidget.swift
//  Widget
//
//  Created by Tiankai Ma on 2026/1/12.
//

import SwiftData
import SwiftUI
import WidgetKit

struct ExamNextProvider: TimelineProvider {
    func makeEntry(for _date: Date = Date()) -> ExamNextEntry {
        return ExamNextEntry()
    }

    func placeholder(in _: Context) -> ExamNextEntry {
        return makeEntry()
    }

    func getSnapshot(in _: Context, completion: @escaping (ExamNextEntry) -> Void) {
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

struct ExamNextEntry: TimelineEntry {
    let date = Date()
}

struct ExamNextWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: ExamNextProvider.Entry

    @Query(sort: \Exam.startDate, order: .forward) var _exams: [Exam]

    var exam: Exam? {
        _exams.filter { !$0.isFinished }.first
    }

    var body: some View {
        VStack {
            ExamDayWidget(exam: exam)
        }
        .padding(3)
        .widgetBackground(Color.clear)
    }
}

struct ExamNextWidget: Widget {
    let kind: String = "ExamNextWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ExamNextProvider()) { entry in
            ExamNextWidgetEntryView(entry: entry)
                .modelContainer(SwiftDataStack.modelContainer)
        }
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
        ])
        .configurationDisplayName(LocalizedStringKey("Next Exam"))
        .description(LocalizedStringKey("Show the next upcoming exam"))
    }
}
