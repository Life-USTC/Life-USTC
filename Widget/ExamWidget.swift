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
    func placeholder(in _: Context) -> SimpleEntry {
        SimpleEntry.example
    }

    func getSnapshot(in _: Context, completion: @escaping (SimpleEntry) -> Void) {
        Task {
            let exams = try await _exams.retrive() ?? []
            let entry = SimpleEntry(exams: exams)
            completion(entry)
        }
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            var exams = try await _exams.retrive() ?? []
            exams = Exam.show(exams)
            let entry = SimpleEntry(exams: exams)

            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date = Date()
    let exams: [Exam]

    static let example = SimpleEntry(exams: [Exam.example])
}

struct ExamWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: ExamProvider.Entry

    var exam: Exam {
        entry.exams.filter { !$0.isFinished }.first ?? .example
    }

    var exams: [Exam] {
        entry.exams.isEmpty ? [.example] : entry.exams
    }

    var numberToShow: Int {
        switch widgetFamily {
        case .systemMedium:
            return 2
        case .systemLarge:
            return 6
        case .systemExtraLarge:
            return 6
        default:
            return 0
        }
    }

    var noMoreExamView: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles.square.filled.on.square")
                .font(.system(size: 50))
                .foregroundColor(.blue.opacity(0.8))
            Text("No Exams!")
                .font(.system(.body, design: .rounded))
                .foregroundColor(.secondary)
        }
    }

    var examSymbolView: some View {
        Text("Exam")
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.blue.opacity(0.8))
            )
    }

    var mainView: some View {
        VStack(alignment: .leading) {
            HStack {
                examSymbolView
                Text(exam.startDate, format: .dateTime.day().month())
                    .font(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundColor(.blue.opacity(0.8))
            }
            Text(exam.courseName)
                .lineLimit(2)
                .fontWeight(.bold)
            Spacer()
            HStack(alignment: .lastTextBaseline) {
                Text(
                    exam.daysLeft == 1
                        ? "1 day left".localized
                        : String(format: "%@ days left".localized, String(exam.daysLeft))
                )
                .foregroundColor(exam.daysLeft <= 7 ? .red.opacity(0.8) : .blue.opacity(0.8))
                .font(.title3)
                .fontWeight(.semibold)
            }
            HStack {
                Text(exam.startDate, format: .dateTime.hour().minute())
                Spacer()
                Text(exam.classRoomName)
            }
            .lineLimit(1)
            .foregroundColor(.secondary)
            .font(.subheadline)
            .fontWeight(.regular)
        }
        .scenePadding()
        .if(entry.exams.filter { !$0.isFinished }.isEmpty) { view in
            view
                .redacted(reason: .placeholder)
                .blur(radius: 10)
                .overlay {
                    noMoreExamView
                }
        }
    }

    var oneLine: some View {
        Text(
            String(
                format: "%@+%@D".localized,
                exam.courseName.truncated(),
                String(exam.daysLeft)
            )
        )
    }

    var listView: some View {
        VStack(alignment: .leading, spacing: 5) {
            examSymbolView
            ForEach(exams.prefix(numberToShow), id: \.lessonCode) { exam in
                Divider()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(exam.courseName)
                                .font(.headline)
                                .strikethrough(exam.isFinished)
                                .bold()
                            Text(exam.typeName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text(exam.startDate, format: .dateTime.day().month())
                                .font(.footnote)
                                .fontWeight(.heavy)
                                .foregroundColor(.blue.opacity(0.8))
                            Text(exam.detailString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if exam.isFinished {
                        Text("Finished".localized)
                            .foregroundColor(.gray)
                            .font(.subheadline)
                            .fontWeight(.heavy)
                    } else {
                        Text(
                            exam.daysLeft == 1
                                ? "1 day left".localized
                                : String(format: "%@ days left".localized, String(exam.daysLeft))
                        )
                        .foregroundColor(
                            exam.daysLeft <= 7 ? .red.opacity(0.8) : .blue.opacity(0.8)
                        )
                        .font(.subheadline)
                        .fontWeight(.heavy)
                    }
                }
            }
            Spacer()
        }
        .scenePadding()
    }

    var shortListView: some View {
        VStack(alignment: .leading) {
            Text("Exams:")
                .font(.body)
                .fontWeight(.semibold)
            ForEach(exams.prefix(2), id: \.lessonCode) { exam in
                HStack {
                    Text(exam.courseName)
                        .strikethrough(exam.isFinished)
                    if !exam.isFinished {
                        Text("+\(String(exam.daysLeft))D")
                    } else {
                        Text("Finished".localized)
                    }
                }
            }
        }
        .font(.caption)
        .scenePadding()
    }

    var body: some View {
        Group {
            switch widgetFamily {
            case .systemSmall:
                mainView
            case .systemMedium:
                listView
            case .systemLarge:
                listView
            case .systemExtraLarge:
                listView
            case .accessoryInline:
                oneLine
            case .accessoryRectangular:
                shortListView
            default:
                mainView
            }
        }
        .if(entry.exams.isEmpty) { view in
            view
                .redacted(reason: .placeholder)
                .blur(radius: 10)
                .overlay {
                    noMoreExamView
                }
        }
    }
}

struct ExamWidget: Widget {
    let kind: String = "ExamWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ExamProvider()) { entry in
            ExamWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Exams")
        .description("Show upcoming exam.")
        .supportedFamilies(WidgetFamily.allCases)
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
