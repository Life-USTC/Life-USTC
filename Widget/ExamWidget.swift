//
//  ExamWidget.swift
//  ExamWidget
//
//  Created by TiankaiMa on 2023/1/22.
//

import Intents
import SwiftUI
import WidgetKit

struct ExamProvider: TimelineProvider {
    @ManagedData(.exam) var exams: [Exam]
    @AppStorage("widgetCanRefreshNewData", store: .appGroup) var _widgetCanRefreshNewData: Bool? = nil

    var canRefresh: Bool {
        _widgetCanRefreshNewData ?? false
    }

    func placeholder(in _: Context) -> ExamEntry {
        ExamEntry.example
    }

    func makeEntry(for _date: Date = Date()) async throws -> ExamEntry {
        guard let exams = try await canRefresh ? _exams.retrive() : _exams.retriveLocal() else {
            throw BaseError.runtimeError("Failed to retrive exams")
        }

        return ExamEntry(exams: exams.clean())
    }

    func getSnapshot(in _: Context, completion: @escaping (ExamEntry) -> Void) {
        Task {
            let entry = try await makeEntry()
            completion(entry)
        }
    }

    func getTimeline(
        in _: Context,
        completion: @escaping (Timeline<Entry>) -> Void
    ) {
        Task {
            let entry = try await makeEntry()

            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
}

struct ExamEntry: TimelineEntry {
    let date = Date()
    let exams: [Exam]

    static let example = ExamEntry(exams: [Exam.example])
}

struct ExamWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: ExamProvider.Entry

    var body: some View {
        VStack {
            if widgetFamily == .systemMedium {
                ExamPreview()
                    .makeListWidget(
                        with: entry.exams,
                        numberToShow: 2
                    )
            } else if widgetFamily == .systemLarge {
                ExamPreview()
                    .makeListWidget(
                        with: entry.exams,
                        numberToShow: 6
                    )
            } else if widgetFamily == .systemSmall {
                ExamPreview()
                    .makeWidget(
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

struct ExamWidget_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(WidgetFamily.allCases, id: \.rawValue) { family in
            ExamWidgetEntryView(entry: .example)
                .previewContext(WidgetPreviewContext(family: family))
                .previewDisplayName(family.description)
        }

        ForEach(WidgetFamily.allCases, id: \.rawValue) { family in
            ExamWidgetEntryView(entry: .init(exams: []))
                .previewContext(WidgetPreviewContext(family: family))
                .previewDisplayName("\(family.description) [EMPTY]")
        }
    }
}
