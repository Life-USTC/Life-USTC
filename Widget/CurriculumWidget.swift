//
//  CurriculumWidget.swift
//  CurriculumWidget
//
//  Created by Ode on 2023/3/7.
//

import Intents
import SwiftUI
import WidgetKit

struct CurriculumProvider: TimelineProvider {
    func placeholder(in _: Context) -> CurriculumEntry {
        CurriculumEntry.example
    }

    func getSnapshot(in _: Context, completion: @escaping (CurriculumEntry) -> Void) {
        Task {
            let entry = CurriculumEntry(courses: try await Curriculum.sharedDelegate.retrive().todaysCourse)
            completion(entry)
        }
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            let entry = CurriculumEntry(courses: try await Curriculum.sharedDelegate.retrive().todaysCourse)

            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
}

struct CurriculumEntry: TimelineEntry {
    let date = Date()
    let courses: [Course]

    static let example = CurriculumEntry(courses: [Course.example])
}

struct CurriculumWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: CurriculumProvider.Entry

    var course: Course {
        entry.courses.filter { !$0.isFinished(at: Date()) }.first ?? .example
    }

    var courses: [Course] {
        entry.courses.isEmpty ? [.example] : entry.courses
    }

    var numberToShow: Int {
        switch widgetFamily {
        case .systemSmall:
            return 1
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

    var noMoreCurriculumView: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles.square.filled.on.square")
                .font(.system(size: 50))
                .foregroundColor(.mint.opacity(0.8))
            Text("No courses today!")
                .font(.system(.body, design: .rounded))
                .foregroundColor(.secondary)
        }
    }

    var allFinishedToday: Bool {
        entry.courses.filter { !$0.isFinished(at: Date()) }.isEmpty
    }

    var courseSymbolView: some View {
        Text("Class")
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.mint.opacity(0.8))
            )
    }

    var mainView: some View {
        VStack(alignment: .leading) {
            HStack {
                courseSymbolView
                Text(course.classPositionString)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundColor(.mint)
            }
            Text(course.name)
                .lineLimit(2)
                .fontWeight(.bold)
            Spacer()
            Text(course._startTime.clockTime)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.mint)
            HStack {
                Text(course._endTime.clockTime)
                Spacer()
                Text(course.classTeacherName)
            }
            .font(.subheadline)
            .fontWeight(.regular)
            .foregroundColor(.secondary)
        }
        .scenePadding()
    }

    var oneLine: some View {
        Text(String(format: "%@ - %@".localized,
                    course.name.limitShow(1),
                    course._startTime.clockTime))
    }

    var listView: some View {
        VStack(alignment: .leading, spacing: 5) {
            courseSymbolView
            ForEach(courses.prefix(numberToShow)) { course in
                Divider()
                HStack {
                    VStack(alignment: .leading) {
                        Text(course.name)
                            .font(.headline)
                            .fontWeight(.bold)
                        HStack {
                            Text(course.detailString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(course._startTime.clockTime)
                            .font(.subheadline)
                            .fontWeight(.heavy)
                            .foregroundColor(.mint)
                        Text(course._endTime.clockTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
        .scenePadding()
    }

    var smallView: some View {
        VStack(alignment: .leading) {
            Text(course.name.truncated(length: 4))
                .font(.body)
                .fontWeight(.semibold)
            Text(course._startTime.clockTime)
            Text(course.classPositionString)
        }
        .scenePadding()
    }

    var body: some View {
        Group {
            switch widgetFamily {
            case .systemSmall:
                mainView
                    .if(allFinishedToday) { view in
                        view
                            .redacted(reason: .placeholder)
                            .blur(radius: 10)
                            .overlay {
                                noMoreCurriculumView
                            }
                    }
            case .systemMedium:
                listView
            case .systemLarge:
                listView
            case .systemExtraLarge:
                listView
            case .accessoryInline:
                oneLine
            case .accessoryRectangular:
                smallView
            default:
                oneLine
            }
        }
        .if(entry.courses.isEmpty) { view in
            view
                .redacted(reason: .placeholder)
                .blur(radius: 10)
                .overlay {
                    noMoreCurriculumView
                }
        }
    }
}

private extension Course {
    var detailString: String {
        "\(classTeacherName) @ \(classPositionString)"
    }
}

struct CurriculumWidget: Widget {
    let kind: String = "CurriculumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurriculumProvider()) { entry in
            CurriculumWidgetEntryView(entry: entry)
        }
        .supportedFamilies(WidgetFamily.allCases)
        .configurationDisplayName("Curriculum")
        .description("Show today's curriculum.")
    }
}

struct CurriculumWidget_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(WidgetFamily.allCases, id: \.rawValue) { family in
            CurriculumWidgetEntryView(entry: .example)
                .previewContext(WidgetPreviewContext(family: family))
                .previewDisplayName(family.description)
        }

        ForEach(WidgetFamily.allCases, id: \.rawValue) { family in
            CurriculumWidgetEntryView(entry: .init(courses: []))
                .previewContext(WidgetPreviewContext(family: family))
                .previewDisplayName("\(family.description) [EMPTY]")
        }
    }
}
