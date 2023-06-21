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
            let courses = try await CurriculumDelegate.shared.retrive()
            let weekNumber = UstcUgAASClient.shared.weekNumber()
            let entry = CurriculumEntry(courses: Course.filter(courses, week: weekNumber))
            completion(entry)
        }
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            let courses = try await CurriculumDelegate.shared.retrive()
            let weekNumber = UstcUgAASClient.shared.weekNumber()
            let entry = CurriculumEntry(courses: Course.filter(courses, week: weekNumber))

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

    var courseToShow: Course! {
        entry.courses.filter { !$0.isFinished(at: Date()) }.first ?? Course.example
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
        VStack(alignment: .center, spacing: 20) {
            Image(systemName: "moon.stars")
                .font(.system(size: 50))
                .fontWeight(.regular)
                .frame(width: 60, height: 60)
                .padding(5)
                .fontWeight(.heavy)
                .foregroundColor(.mint.opacity(0.8))
            Text("No courses today!")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding()
    }

    var mainView: some View {
        VStack(alignment: .leading) {
            VStack (alignment: .leading) {
                HStack {
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
                    Text(courseToShow.classPositionString)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundColor(.mint)
                }
                Text(courseToShow.name)
                    .lineLimit(2)
                    .fontWeight(.bold)
            }
            Spacer()
            VStack(alignment: .leading) {
                Text(courseToShow._startTime.clockTime)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.mint)
                HStack {
                    Text(courseToShow._endTime.clockTime)
                    Spacer()
                    Text(courseToShow.classTeacherName)
                }
                .font(.subheadline)
                .fontWeight(.regular)
                .foregroundColor(.gray.opacity(0.8))
            }
        }
        .padding(15)
    }

    var oneLine: some View {
        Text(String(format: "%@ - %@".localized,
                    courseToShow.name.limitShow(1),
                    courseToShow._startTime.clockTime))
    }

    var listView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Class")
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.mint)
            )
            ForEach(entry.courses.prefix(numberToShow)) { course in
                Divider()
                    .padding(.vertical, 2)
                HStack {
                    VStack(alignment: .leading) {
                        Text(course.name)
                            .font(.headline)
                            .fontWeight(.bold)
                        HStack {
                            Text("\(course.classTeacherName) @ \(course.classPositionString)")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.8))
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
                            .foregroundColor(.gray.opacity(0.8))
                    }
                }
            }
            Spacer()
        }
        .font(.footnote)
        .padding(.horizontal, 15)
        .padding(.vertical, 20)
    }

    var smallView: some View {
        VStack(alignment: .leading) {
            Text(courseToShow.name.truncated(length: 4))
                .font(.body)
                .fontWeight(.semibold)
            Text(courseToShow._startTime.clockTime)
            Text(courseToShow.classPositionString)
        }
        .padding(1)
    }

    var body: some View {
        if entry.courses.isEmpty {
            noMoreCurriculumView
        } else {
            switch widgetFamily {
            case .systemSmall:
                if entry.courses.first(where: { !$0.isFinished(at: Date()) }) == nil {
                    noMoreCurriculumView
                } else {
                    mainView
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
