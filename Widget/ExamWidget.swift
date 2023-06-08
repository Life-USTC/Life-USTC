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
            let exams = try await ExamDelegate.shared.retrive()
            let entry = SimpleEntry(exams: exams)
            completion(entry)
        }
    }

    func getTimeline(for _: ConfigurationIntent, in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            var exams = try await ExamDelegate.shared.retrive()
            exams = Exam.show(exams)
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
            return 4
        case .systemExtraLarge:
            return 6
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

            Text("No Exam")

            Spacer()

            Text("Open the app to make sure though...")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding()
    }

    var mainView: some View {
        VStack(alignment: .leading) {
            VStack (alignment: .leading) {
                HStack {
                    Text("Exam")
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .font(.callout)
                        .fontWeight(.heavy)
                        .foregroundColor(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.blue.opacity(0.8))
                    )
                    Text(exam.startTime, format: .dateTime.day().month())
                        .font(.callout)
                        .fontWeight(.heavy)
                        .lineLimit(1)
                        .foregroundColor(.blue.opacity(0.8))
                }
                Text(exam.className)
                    .lineLimit(2)
                    .fontWeight(.bold)
            }
            Spacer()
            VStack (alignment: .leading){
                HStack (alignment: .lastTextBaseline) {
                    Text(String(exam.daysLeft) + " Days Left")
                        .font(.title3)
                        .fontWeight(.heavy)
                        .foregroundColor(.blue.opacity(0.8))
                }
                HStack {
                    Text(exam.startTime, format: .dateTime.hour().minute())
                    Spacer()
                    Text(exam.classRoomName)
                }
                .lineLimit(1)
                .foregroundColor(.gray.opacity(0.8))
                .font(.subheadline)
                .fontWeight(.semibold)
            }
        }
        .padding(15)
    }

    var oneLine: some View {
        Text(String(format: "%@+%@D".localized,
                    exam.className.limitShow(6),
                    String(exam.daysLeft)))
    }

    var listView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Exam")
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .font(.callout)
                .fontWeight(.heavy)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.blue.opacity(0.8))
                )
            ForEach(entry.exams.prefix(numberToShow)) { exam in
                Divider()
                    .padding(.vertical, 2)
                HStack (alignment: .bottom) {
                    VStack (alignment: .leading) {
                        Text(exam.className)
                            .font(.headline)
                            .strikethrough(exam.isFinished)
                            .bold()
                        HStack {
                            Text(exam.startTime, format: .dateTime.day().month())
                                .fontWeight(.heavy)
                                .foregroundColor(.blue.opacity(0.8))
                            Text(exam.timeDescription)
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.8))
                            Text("@\(exam.classRoomName)")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.8))
                        }
                    }
                    Spacer()
                    if exam.isFinished {
                        Text("Finished".localized)
                            .foregroundColor(.gray)
                            .font(.subheadline)
                            .fontWeight(.heavy)
                    } else {
                        Text(exam.daysLeft == 1 ?
                            "1 day left".localized :
                            String(format: "%@ days left".localized, String(exam.daysLeft)))
                            .foregroundColor(exam.daysLeft <= 7 ? .red.opacity(0.8) : .blue.opacity(0.8))
                            .font(.subheadline)
                            .fontWeight(.heavy)
                    }
                }
            }
            Spacer()
        }
        .font(.footnote)
        .padding(.horizontal, 15)
        .padding(.vertical, 20)
    }

    var shortListView: some View {
        VStack(alignment: .leading) {
            Text("Exams:")
                .bold()
            ForEach(entry.exams.prefix(2)) { exam in
                HStack {
                    Text(exam.className)
                        .bold()
                        .strikethrough(exam.isFinished)
                    Spacer()
                    if !exam.isFinished {
                        Text("+\(String(exam.daysLeft))D")
                    } else {
                        Text("Finished".localized)
                            .bold()
                    }
                }
                .foregroundColor(exam.daysLeft <= 7 ? .primary : .red)
            }
            Spacer()
        }
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
