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
        entry.courses.filter { !$0.isFinished(at: Date()) }.first
    }

    var numberToShow: Int {
        switch widgetFamily {
        case .systemSmall:
            return 1
        case .systemMedium:
            return 4
        case .systemLarge:
            return 7
        case .systemExtraLarge:
            return 7
        default:
            return 0
        }
    }

    var noMoreCurriculumView: some View {
        VStack {
            Spacer()

            Image(systemName: "moon.stars")
                .font(.largeTitle)
                .fontWeight(.regular)
                .foregroundColor(.accentColor)

            Text("No more course today!")

            Spacer()

            Text("Open the app to make sure though...")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding()
    }

    var mainView: some View {
        VStack(alignment: .center, spacing: 7) {
            Text(courseToShow.name)
                .lineLimit(2)
                .font(.headline)
            VStack(alignment: .center, spacing: -3) {
                HStack {
                    Text(courseToShow._startTime.clockTime)
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
                HStack {
                    Text(courseToShow._endTime.clockTime)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            VStack {
                Text(courseToShow.classPositionString)
                    .lineLimit(1)
                    .font(.callout)
                    .foregroundColor(.accentColor)
                Text(courseToShow.classTeacherName)
                    .lineLimit(1)
                    .foregroundColor(.gray)
                    .font(.caption2)
            }
        }
        .padding()
    }

    var oneLine: some View {
        Text(String(format: "%@ - %@".localized,
                    courseToShow.name.limitShow(1),
                    courseToShow._startTime.clockTime))
    }

    var listView: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "moon.stars")
                Text("Today's Course")
                    .bold()
            }
            .foregroundColor(.accentColor)

            ForEach(entry.courses.prefix(numberToShow)) { course in
                Divider()
                HStack {
                    Text(course.name.limitShow(1))
                        .bold()
                    Spacer()
                    Text("@\(course.classPositionString)")
                        .foregroundColor(.gray)
                    Text(course._startTime.clockTime + " - " + course._endTime.clockTime)
                }
            }

            Divider()

            if entry.courses.count > numberToShow, min(numberToShow, entry.courses.count) < 7 {
                Text("+\(String(entry.courses.count - numberToShow)) More Courses...")
                    .foregroundColor(.accentColor)
            }

            if entry.courses.count < numberToShow {
                Spacer()
            }
        }
        .font(.footnote)
        .padding()
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
