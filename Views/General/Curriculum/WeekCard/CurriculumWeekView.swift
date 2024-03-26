//
//  CurriculumWeekView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/20.
//

import Charts
import SwiftUI

struct CurriculumWeekView: View {
    var lectures: [Lecture]
    var _date: Date
    var currentSemesterName: String
    var weekNumber: Int?
    var fontSize: Double = 10

    var date: Date {
        _date.startOfWeek()
    }
    var behavior: CurriculumBehavior {
        SchoolExport.shared.curriculumBehavior
    }
    var mergedTimes: [Int] {
        (behavior.shownTimes + behavior.highLightTimes).sorted()
    }

    var body: some View {
        VStack {
            HStack {
                Text(date ... date.add(day: 6))

                if let weekNumber {
                    Spacer()

                    Text("Week \(weekNumber)")
                }

                Spacer()

                Text(currentSemesterName)
            }
            .font(.system(.caption2, design: .monospaced, weight: .light))

            mainView
        }
    }

    var mainView: some View {
        Chart {
            if (date ... date.add(day: 7)).contains(Date().stripTime()) {
                // See GH#2
                BarMark(
                    xStart: .value(
                        "Start Time",
                        mergedTimes.first!
                    ),

                    xEnd: .value(
                        "End Time",
                        mergedTimes.last!
                    ),
                    y: .value("Date", Date().stripTime(), unit: .day)
                )
                .foregroundStyle(Color.accentColor.opacity(0.2))
            }

            ForEach(lectures) { lecture in
                BarMark(
                    xStart: .value(
                        "Start Time",
                        behavior.convertTo(lecture.startDate.HHMM)
                    ),

                    xEnd: .value(
                        "End Time",
                        behavior.convertTo(lecture.endDate.HHMM)
                    ),
                    y: .value("Date", lecture.startDate.stripTime(), unit: .day)
                )
                .foregroundStyle(by: .value("Course Name", lecture.name.truncated(length: 6)))
                .annotation(position: .overlay) {
                    Text(lecture.name)
                        .font(.system(size: fontSize))
                        .foregroundColor(.white)
                }
            }
        }
        .chartXAxis {
            AxisMarks(position: .top, values: behavior.shownTimes) { value in
                if let _hhmm = value.as(Int.self) {
                    let hhmm = behavior.convertFrom(_hhmm)
                    AxisValueLabel {
                        Text(
                            "\(hhmm / 60, specifier: "%02d"):\(hhmm % 60, specifier: "%02d")"
                        )
                        .font(.system(size: fontSize - 1))
                    }
                    AxisGridLine()
                }
            }

            if (mergedTimes.first! ... mergedTimes.last!)
                .contains(behavior.convertTo(Date().stripDate().HHMM))
            {
                AxisMarks(
                    position: .bottom,
                    values: [behavior.convertTo(Date().stripDate().HHMM)]
                ) { _ in
                    AxisGridLine(stroke: .init(dash: []))
                        .foregroundStyle(.red)
                }
            }

            AxisMarks(position: .bottom, values: behavior.highLightTimes) {
                value in
                if let _hhmm = value.as(Int.self) {
                    let hhmm = behavior.convertFrom(_hhmm)
                    AxisValueLabel(anchor: .topTrailing) {
                        Text(
                            "\(hhmm / 60, specifier: "%02d"):\(hhmm % 60, specifier: "%02d")"
                        )
                        .foregroundColor(.blue)
                    }
                    AxisGridLine()
                        .foregroundStyle(.blue)
                }
            }
        }
        .chartXScale(domain: mergedTimes.first! ... mergedTimes.last!)
        .chartYAxis {
            AxisMarks(position: .leading, values: .stride(by: .day)) { _ in
                AxisGridLine()
            }

            AxisMarks(position: .leading, values: [date.add(day: 7)]) { _ in
                AxisGridLine()
            }
        }
        .chartYScale(domain: date ... date.add(day: 7))
        .if(lectures.isEmpty) {
            $0
                .redacted(reason: .placeholder)
                .blur(radius: 2)
                .overlay {
                    Text("No lectures this week")
                        .font(.system(.title2, design: .rounded))
                        .foregroundColor(.secondary)
                }
        }
    }
}

fileprivate let daysOfWeek: [String] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
//fileprivate let heightPerClass = 60.0

struct LectureSheetModifier: ViewModifier {
    var lecture: Lecture
    @State var showPopUp: Bool = false
    @ManagedData(.buildingImgMapping) var buildingImgMapping

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                showPopUp = true
            }
            .sheet(isPresented: $showPopUp) {
                NavigationStack {
                    VStack {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading) {
                                HStack(alignment: .bottom) {
                                    Text(lecture.name)
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .background {
                                            GeometryReader { geo in
                                                HStack {
                                                    Rectangle()
                                                        .fill(Color.accentColor.opacity(0.2))
                                                        .frame(width: geo.size.width + 10, height: geo.size.height / 2)
                                                    
                                                    Rectangle()
                                                        .fill(Color.secondary.opacity(0.6))
                                                        .frame(width: 2, height: geo.size.height + 10)
                                                        .rotationEffect(.degrees(20))
                                                        .offset(x: -7)
                                                }
                                            }
                                        }
                                    
                                    if let code = lecture.course?.lessonCode {
                                        Spacer()
                                            .frame(width: 20)
                                        
                                        Text(code)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .bold()
                                    }
                                }
                                Text(lecture.startDate.clockTime + "-" + lecture.endDate.clockTime + " @ " + lecture.location)
                                    .foregroundStyle(.secondary)
                                    .bold()
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading) {
                                HStack(alignment: .bottom) {
                                    Text("Teacher: ".localized)
                                        .foregroundStyle(.secondary)
                                    Text(lecture.teacherName)
                                }
                                if let credit = lecture.course?.credit {
                                    HStack(alignment: .bottom) {
                                        Text("Credit: ".localized)
                                            .foregroundStyle(.secondary)
                                        Text(String(credit))
                                    }
                                }
                            }
                            .font(.caption)
                        }
                        .padding([.top, .horizontal])
                        
                        if let url = buildingImgMapping.getURL(buildingName: lecture.location) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(maxWidth: .infinity, maxHeight: 400)
                            .padding(5)
                        }
                        
                        Spacer()
                    }
                }
                .presentationDetents([.fraction(0.45)])
            }
    }
}

extension View {
    func lectureSheet(lecture: Lecture) -> some View {
        modifier(LectureSheetModifier(lecture: lecture))
    }
}

struct LectureCardView: View {
    var lecture: Lecture
    
    var length: Int {
        (lecture.endIndex ?? 0) - (lecture.startIndex ?? 0) + 1
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(lecture.startDate.stripTime() == Date().stripTime() ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.accentColor.opacity(0.1), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(lecture.startDate.clockTime)
                    .font(.system(size: 10))
                    .fontWeight(.bold)
                Text(lecture.name)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2, reservesSpace: false)
                    .font(.system(size: 15, weight: .light))
                Text(lecture.location)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2, reservesSpace: false)
                    .font(.system(size: 13, weight: .light, design: .monospaced))
                
                Spacer()

                if length > 2 {
                    Text(lecture.teacherName)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2, reservesSpace: false)
                        .font(.system(size: 10))
                        .hStackTrailing()
                }

                Text(lecture.endDate.clockTime)
                    .font(.system(size: 10, weight: .bold))
                    .hStackTrailing()
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 5)
        }
        .lectureSheet(lecture: lecture)
    }
}

struct CurriculumWeekViewVerticalNew: View {
    var lectures: [Lecture]
    var _date: Date
    var currentSemesterName: String
    var weekNumber: Int?
    var hideWeekend: Bool
    
    var date: Date {
        _date.startOfWeek()
    }
    
    @ViewBuilder
    func makeVStack(index: Int, heightPerClass: Double) -> some View {
        VStack {
            Text(daysOfWeek[index])
                .font(.system(.caption2, design: .monospaced, weight: .light))
            
            ZStack(alignment: .top) {
                Color.clear
                
                ForEach(lectures.filter {(date.add(day: index) ... date.add(day: index + 1)).contains($0.startDate)}) { lecture in
                    LectureCardView(lecture: lecture)
                        .frame(height: heightPerClass * Double((lecture.endIndex ?? 0) - (lecture.startIndex ?? 0) + 1) - 4)
                        .offset(y: Double((lecture.startIndex ?? 1) - 1) * heightPerClass + 2)
                        .padding(2)
                }
                
                Rectangle()
                    .fill(Color.accentColor.opacity(0.4))
                    .frame(height: 1)
                    .offset(y: 5 * heightPerClass + 1.5)
                    .opacity(0.5)
                
                Rectangle()
                    .fill(Color.accentColor.opacity(0.4))
                    .frame(height: 1)
                    .offset(y: 10 * heightPerClass + 1.5)
                    .opacity(0.5)
            }
        }
    }
    
    var body: some View {
        if hideWeekend {
            GeometryReader { geo in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(1..<6) { index in
                        makeVStack(index: index, heightPerClass: geo.size.height / 13)
                            .frame(width: geo.size.width / 5, height: geo.size.height)
                    }
                }
            }
            .padding(.horizontal, 20)
        } else {
            GeometryReader { geo in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<7) { index in
                        makeVStack(index: index, heightPerClass: geo.size.height / 13)
                            .frame(width: geo.size.width / 7, height: geo.size.height)
                    }
                }
            }
        }
    }
}

struct CurriculumWeekViewVertical: View {
    var lectures: [Lecture]
    var _date: Date
    var currentSemesterName: String
    var weekNumber: Int?
    var fontSize: Double = 10

    var date: Date {
        _date.startOfWeek()
    }
    var behavior: CurriculumBehavior {
        SchoolExport.shared.curriculumBehavior
    }
    var mergedTimes: [Int] {
        (behavior.shownTimes + behavior.highLightTimes).sorted()
    }

    var body: some View {
        Chart {
            if (date ... date.add(day: 7)).contains(Date().stripTime()) {
                // See GH#2
                BarMark(
                    x: .value("Date", Date().stripTime(), unit: .day),
                    yStart: .value(
                        "Start Time",
                        -mergedTimes.first!
                    ),

                    yEnd: .value(
                        "End Time",
                        -mergedTimes.last!
                    )
                )
                .foregroundStyle(Color.accentColor.opacity(0.2))
            }

            ForEach(lectures) { lecture in
                BarMark(
                    x: .value("Date", lecture.startDate.stripTime(), unit: .day),
                    yStart: .value(
                        "Start Time",
                        -behavior.convertTo(lecture.startDate.HHMM)
                    ),

                    yEnd: .value(
                        "End Time",
                        -behavior.convertTo(lecture.endDate.HHMM)
                    )
                )
                .foregroundStyle(by: .value("Course Name", lecture.name.truncated(length: 6)))
                .annotation(position: .overlay) {
                    VStack {
                        Text(lecture.name)
                            .font(.system(size: fontSize))
                            .multilineTextAlignment(.center)
                        Text(lecture.location)
                            .font(.system(size: fontSize - 1))
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom, values: .stride(by: .day)) { _ in
                AxisGridLine()
            }
        }
        .chartXScale(domain: date ... date.add(day: 7))
        .chartYAxis {
            AxisMarks(position: .leading, values: behavior.shownTimes.map { -$0 }) { value in
                if let _hhmm = value.as(Int.self) {
                    let hhmm = behavior.convertFrom(-_hhmm)
                    AxisValueLabel(anchor: .topTrailing) {
                        Text(
                            "\(hhmm / 60, specifier: "%02d"):\(hhmm % 60, specifier: "%02d")"
                        )
                    }
                    AxisGridLine()
                }
            }

            AxisMarks(position: .leading, values: behavior.highLightTimes.map { -$0 }) {
                value in
                if let _hhmm = value.as(Int.self) {
                    let hhmm = behavior.convertFrom(-_hhmm)
                    AxisValueLabel(anchor: .bottomTrailing) {
                        Text(
                            "\(hhmm / 60, specifier: "%02d"):\(hhmm % 60, specifier: "%02d")"
                        )
                        .foregroundColor(.blue)
                    }
                    AxisGridLine()
                        .foregroundStyle(.blue)
                }
            }
        }
        .chartYScale(domain: -mergedTimes.last! ... -mergedTimes.first!)
        .if(lectures.isEmpty) {
            $0
                .redacted(reason: .placeholder)
                .blur(radius: 2)
                .overlay {
                    Text("No lectures this week")
                        .font(.system(.title2, design: .rounded))
                        .foregroundColor(.secondary)
                }
        }
    }
}
