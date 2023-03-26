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
            let curriculums = try await CurriculumDelegate.shared.retrive()
            let entry = CurriculumEntry(curriculums: curriculums)
            completion(entry)
        }
    }

    func getTimeline(for _: ConfigurationIntent, in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            let curriculums = try await CurriculumDelegate.shared.retrive()
            let entry = CurriculumEntry(curriculums: curriculums)

            let date = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(date))
            completion(timeline)
        }
    }
}

struct CurriculumEntry: TimelineEntry {
    let date = Date()
    let curriculums: [Course]
    var configuration = ConfigurationIntent()

    static let example = CurriculumEntry(curriculums: [Course].init(repeating: .example, count: 10),
                                         configuration: ConfigurationIntent())
}

struct CurriculumWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: CurriculumProvider.Entry

    var courses: [Course] {
        entry.curriculums.filter { $0.dayOfWeek == currentWeekDay }.sorted(by: { $0.startTime < $1.startTime })
    }

    var courseToShow: Course {
        courses.first { Date().stripTime() + Course.endTimes[$0.endTime - 1] > Date() } ?? .example
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

            Text("Free today!")

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
                    Text(Course.startTimes[courseToShow.startTime - 1].clockTime)
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
                HStack {
                    Text(Course.endTimes[courseToShow.endTime - 1].clockTime)
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
                    Course.startTimes[courseToShow.startTime - 1].clockTime))
    }

    var listView: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "moon.stars")
                Text("Upcoming Course")
                    .bold()
            }
            .foregroundColor(.accentColor)

            ForEach(courses.prefix(numberToShow)) { course in
                Divider()
                HStack {
                    Text(course.name.limitShow(1))
                        .bold()
                    Spacer()
                    Text("@\(course.classPositionString)")
                        .foregroundColor(.gray)
                    Text(Course.startTimes[course.startTime - 1].clockTime + " - " + Course.endTimes[course.endTime - 1].clockTime)
                }
            }

            Divider()

            if courses.count > numberToShow, min(numberToShow, entry.curriculums.count) < 7 {
                Text("+\(String(entry.curriculums.count - numberToShow)) More Courses...")
                    .foregroundColor(.accentColor)
            }

            if courses.count < numberToShow {
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
        if courses.isEmpty {
            noMoreCurriculumView
        } else {
            switch widgetFamily {
            case .systemSmall:
                if courses.first(where: { Date().stripTime() + Course.endTimes[$0.endTime - 1] > Date() }) == nil {
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
            CurriculumWidgetEntryView(entry: .init(curriculums: []))
                .previewContext(WidgetPreviewContext(family: family))
                .previewDisplayName("\(family.description) [EMPTY]")
        }
    }
}
