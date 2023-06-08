//
//  CurriculumWidget.swift
//  CurriculumWidget
//
//  Created by Ode on 2023/3/7.
//

import Intents
import SwiftUI
import WidgetKit

struct CurriculumProvider: IntentTimelineProvider {
    func placeholder(in _: Context) -> CurriculumEntry {
        CurriculumEntry.example
    }

    func getSnapshot(for _: ConfigurationIntent, in _: Context, completion: @escaping (CurriculumEntry) -> Void) {
        Task {
            let courses = try await CurriculumDelegate.shared.retrive()
            let weekNumber = await UstcUgAASClient.shared.weekNumber()
            let entry = CurriculumEntry(courses: Course.filter(courses, week: weekNumber))
            completion(entry)
        }
    }

    func getTimeline(for _: ConfigurationIntent, in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            let courses = try await CurriculumDelegate.shared.retrive()
            let weekNumber = await UstcUgAASClient.shared.weekNumber()
            let entry = CurriculumEntry(courses: Course.filter(courses, week: weekNumber))

            let date = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(date))
            completion(timeline)
        }
    }
}

struct CurriculumEntry: TimelineEntry {
    let date = Date()
    let courses: [Course]
    var configuration = ConfigurationIntent()

    static let example = CurriculumEntry(courses: [Course].init(repeating: .example, count: 10),
                                         configuration: ConfigurationIntent())
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
            return 5
        case .systemExtraLarge:
            return 5
        default:
            return 0
        }
    }

    var noMoreCurriculumView: some View {
        VStack(alignment: .center, spacing: 20) {
            Image(systemName: "moon.stars")
                .font(.system(size: 30))
                .fontWeight(.regular)
                .frame(width: 40, height: 40)
                .padding(5)
                .fontWeight(.heavy)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.mint)
                )
            Text("No more course today!")
                .font(.system(.headline, design: .monospaced))
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
                        .fontWeight(.heavy)
                        .foregroundColor(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.mint.opacity(0.8))
                        )
                    Text(courseToShow.classPositionString)
                        .font(.callout)
                        .fontWeight(.heavy)
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
                    .fontWeight(.heavy)
                    .foregroundColor(.mint)
                HStack {
                    Text(courseToShow._endTime.clockTime)
                    Spacer()
                    Text(courseToShow.classTeacherName)
                }
                .font(.subheadline)
                .fontWeight(.semibold)
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
                .fontWeight(.heavy)
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
            Text(courseToShow.name.limitShow(1))
            Text(courseToShow.clockTime)
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
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: CurriculumProvider()) { entry in
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
