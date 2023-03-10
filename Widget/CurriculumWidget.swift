
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
    
    var curriculum: Course {
        entry.curriculums.first ?? Course.example
    }
    
    var numberToShow: Int {
        switch widgetFamily {
        case .systemSmall:
            return 1
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
    
    var noMoreCurriculumView: some View {
        VStack {
            Spacer()
            
            Image(systemName: "sparkles")
                .font(.largeTitle)
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
        
        VStack(alignment: .center, spacing: 7)  {
            Text(curriculum.name)
                .lineLimit(2)
                .font(.headline)
            VStack(alignment: .center, spacing: -3) {
                HStack {
                    /* Text("  ")
                        .font(.headline)
                        .padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Color.accentColor))
                    */
                    Text("" + Course.startTimes[curriculum.startTime - 1].clockTime + "")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
                HStack{
                    /*
                    Text("-")
                        .font(.headline)
                        .padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Color.gray))
                    */
                    Text(" " + Course.endTimes[curriculum.endTime - 1].clockTime + " ")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
            }
            VStack {
                Text("\(curriculum.classPositionString)")
                    .lineLimit(1)
                    .font(.callout)
                    .foregroundColor(.accentColor)
                Text("\(curriculum.classTeacherName)")
                    .lineLimit(1)
                    .foregroundColor(.gray)
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }
    var oneLine: some View {
        Text(String(format: "%@ - %@".localized,
                    curriculum.name.limitShow(1),
                    Course.startTimes[curriculum.startTime - 1].clockTime))
    }

    var listView: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "sparkles")
                Text("Upcoming Course")
                    .bold()
            }
            .foregroundColor(.accentColor)
            Spacer()
            ForEach(entry.curriculums.prefix(numberToShow)) { curriculum in
                Divider()
                HStack {
                    Text(curriculum.name)
                        .bold()
                    Spacer()
                    Text(Course.startTimes[curriculum.startTime - 1].clockTime + " - " + Course.endTimes[curriculum.endTime - 1].clockTime)
                    /*if exam.isFinished {
                        Text("Finished".localized)
                            .foregroundColor(.gray)
                            .fontWeight(.bold)
                    } else {
                        Text(exam.daysLeft == 1 ?
                            "1 day left".localized :
                            String(format: "%@ days left".localized, String(exam.daysLeft)))
                            .foregroundColor(exam.daysLeft <= 7 ? .red : .accentColor)
                            .fontWeight(.bold)
                    }*/
                }
                .padding(5)
            }

            Divider()

            if entry.curriculums.count > numberToShow, min(numberToShow, entry.curriculums.count) < 7 {
                Text("+\(String(entry.curriculums.count - numberToShow)) More Courses...")
                    .foregroundColor(.accentColor)
            }

            if entry.curriculums.count < numberToShow {
                Spacer()
            }
            Spacer()
        }
        .font(.footnote)
        .padding()
    }

    var shortListView: some View {
        VStack(alignment: .leading) {
                Text(entry.curriculums[0].name)
                .font(Font.system(size: 13))
                Text("\(Course.startTimes[curriculum.startTime - 1].clockTime)")
                .font(Font.system(size: 13))
                .fontWeight(.bold)
        }
        .padding(1)
    }

    var body: some View {
        if entry.curriculums.isEmpty {
            noMoreCurriculumView
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

struct CurriculumWidget_Previews: PreviewProvider {
    static var previews: some View {
        CurriculumWidgetEntryView(entry: CurriculumEntry.example)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
       CurriculumWidgetEntryView(entry: CurriculumEntry.example)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
        CurriculumWidgetEntryView(entry: CurriculumEntry.example)
            .previewContext(WidgetPreviewContext(family: .systemLarge))
#if os(iOS)
        CurriculumWidgetEntryView(entry: CurriculumEntry.example)
            .previewContext(WidgetPreviewContext(family: .systemExtraLarge))
        CurriculumWidgetEntryView(entry: CurriculumEntry.example)
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
        CurriculumWidgetEntryView(entry: CurriculumEntry.example)
            .previewContext(WidgetPreviewContext(family: .accessoryInline))
#endif
    }
}
