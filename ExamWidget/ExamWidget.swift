//
//  ExamWidget.swift
//  ExamWidget
//
//  Created by TiankaiMa on 2023/1/22.
//

import Intents
import SwiftUI
import WidgetKit

struct Provider: IntentTimelineProvider {
    func placeholder(in _: Context) -> SimpleEntry {
        SimpleEntry.example
    }

    func getSnapshot(for _: ConfigurationIntent, in _: Context, completion: @escaping (SimpleEntry) -> Void) {
        Task {
            let exams = try await UstcUgAASClient.main.examDelegate.retrive()
            let entry = SimpleEntry(exams: exams)
            completion(entry)
        }
    }

    func getTimeline(for _: ConfigurationIntent, in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            let exams = try await UstcUgAASClient.main.examDelegate.retrive()
            let entry = SimpleEntry(exams: exams)

            let date = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(date))
            completion(timeline)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date = Date()
    let exams: [Exam]
    var configuration = ConfigurationIntent()

    static let example = SimpleEntry(exams: [Exam].init(repeating: .example, count: 10),
                                     configuration: ConfigurationIntent())
}

struct ExamWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: Provider.Entry

    var exam: Exam {
        entry.exams.first ?? Exam.example
    }

    var numberToShow: Int {
        switch widgetFamily {
        case .systemMedium:
            return 2
        case .systemLarge:
            return 7
        case .systemExtraLarge:
            return 7
        default:
            return 0
        }
    }

    var noMoreExamView: some View {
        VStack {
            Spacer()

            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundColor(.accentColor)

            Text("No More Exam...")

            Spacer()

            Text("Open the app to make sure though...")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding()
    }

    var mainView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(exam.className)
                    .lineLimit(1)
                    .font(.caption)

                HStack(alignment: .lastTextBaseline) {
                    Text(String(exam.daysLeft))
                        .lineLimit(1)
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Days Left")
                        .font(.caption2)
                }

                Spacer()

                Text("Time: \(exam.timeDescription)")
                    .lineLimit(1)
                    .foregroundColor(.gray)
                    .font(.caption2)

                Text("Location: \(exam.classRoomName)")
                    .lineLimit(1)
                    .foregroundColor(.gray)
                    .font(.caption2)

                Spacer()

                Text("+\(String(entry.exams.count - numberToShow)) More Exam...")
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
            Spacer()
        }
        .padding()
    }

    var oneLine: some View {
        Text(String(format: "%@+%@D".localized,
                    exam.className.limitShow(6),
                    String(exam.daysLeft)))
    }

    var listView: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "sparkles")
                Text("Upcoming Exams")
                    .bold()
            }
            .foregroundColor(.accentColor)

            ForEach(entry.exams.prefix(numberToShow)) { exam in
                Divider()
                Text(exam.className)
                    .strikethrough(exam.isFinished)
                    .bold()
                HStack {
                    Text("\(exam.rawTime) @ \(exam.classRoomName)")
                    Spacer()
                    if exam.isFinished {
                        Text("Finished".localized)
                            .foregroundColor(.gray)
                            .fontWeight(.bold)
                    } else {
                        Text(exam.daysLeft == 1 ?
                            "1 day left".localized :
                            String(format: "%@ days left".localized, String(exam.daysLeft)))
                            .foregroundColor(exam.daysLeft <= 7 ? .red : .accentColor)
                            .fontWeight(.bold)
                    }
                }
            }

            Divider()

            if entry.exams.count > numberToShow, min(numberToShow, entry.exams.count) < 7 {
                Text("+\(String(entry.exams.count - numberToShow)) More Exam...")
                    .foregroundColor(.accentColor)
            }

            if entry.exams.count < numberToShow {
                Spacer()
            }
        }
        .font(.footnote)
        .padding()
    }

    var shortListView: some View {
        VStack(alignment: .leading) {
            Text("Exams:")
                .bold()
            ForEach(entry.exams.prefix(2)) { exam in
                HStack {
                    Text(exam.className)
                        .bold()
                    Spacer()
                    Text("+\(String(exam.daysLeft))D")
                }
                .foregroundColor(exam.daysLeft <= 7 ? .primary : .red)
            }
            Spacer()
        }
        .hStackLeading()
    }

    var body: some View {
        if entry.exams.isEmpty {
            noMoreExamView
        } else {
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
                oneLine
            }
        }
    }
}

struct ExamWidget: Widget {
    let kind: String = "ExamWidget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            ExamWidgetEntryView(entry: entry)
        }
#if os(iOS)
        .supportedFamilies([.systemSmall,
                            .systemMedium,
                            .systemLarge,
                            .accessoryRectangular,
                            .accessoryInline])
#else
            .supportedFamilies([.systemSmall,
                                .systemMedium,
                                .systemLarge])
#endif
            .configurationDisplayName("Exams")
            .description("Show upcoming exam.")
    }
}

struct ExamWidget_Previews: PreviewProvider {
    static var previews: some View {
        ExamWidgetEntryView(entry: SimpleEntry.example)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
        ExamWidgetEntryView(entry: SimpleEntry.example)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
        ExamWidgetEntryView(entry: SimpleEntry.example)
            .previewContext(WidgetPreviewContext(family: .systemLarge))
        ExamWidgetEntryView(entry: SimpleEntry.example)
            .previewContext(WidgetPreviewContext(family: .systemExtraLarge))
#if os(iOS)
        ExamWidgetEntryView(entry: SimpleEntry.example)
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
        ExamWidgetEntryView(entry: SimpleEntry.example)
            .previewContext(WidgetPreviewContext(family: .accessoryInline))
#endif
    }
}
