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
fileprivate let heightPerClass = 60.0

struct LectureCardView: View {
    var lecture: Lecture
    @State var showPopUp = false
    
    var length: Int {
        (lecture.endIndex ?? 0) - (lecture.startIndex ?? 0) + 1
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(lecture.startDate.clockTime)
                .font(.system(size: 9))
                .fontWeight(.bold)
                .hStackLeading()
            VStack(alignment: .center) {
                Text(lecture.name)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .font(.system(size: 12))
                Text(lecture.location)
                    .font(.system(size: 12))
                    .fontWeight(.bold)
            }
            if length != 1 {
                Divider()
                Spacer()
//                Text(course.lessonCode)
//                    .font(.system(size: 9))
                Text(lecture.teacherName)
                    .font(.system(size: 9))
                Text(lecture.endDate.clockTime)
                    .font(.system(size: 9))
                    .hStackTrailing()
            }
        }
        .lineLimit(1)
        .padding(2)
        .frame(height: heightPerClass * Double(length) - 4)
        .background {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.accentColor.opacity(0.1))
        }
        .onAppear {
            debugPrint(lecture)
            debugPrint(length)
        }
        .onTapGesture {}
        .onLongPressGesture(minimumDuration: 0.6) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            showPopUp = true
        }
        .sheet(isPresented: $showPopUp) {
            NavigationStack {
                VStack(alignment: .leading) {
                    Text(lecture.name)
                        .foregroundColor(Color.accentColor)
                        .font(.title)
                        .fontWeight(.bold)
                    Text(lecture.startDate.clockTime + " - " + lecture.endDate.clockTime)
                        .bold()

                    List {
                        HStack {
                            Text("Classroom: ".localized)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(lecture.location)
                        }
                        HStack {
                            Text("Teacher: ".localized)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(lecture.teacherName)
                        }
//                        HStack {
//                            Text("ID: ".localized)
//                                .fontWeight(.semibold)
//                            Spacer()
//                            Text(lecture.lessonCode)
//                        }
//                        HStack {
//                            Text("Week: ".localized)
//                                .fontWeight(.semibold)
//                            Spacer()
//                            Text(lecture.weekString)
//                        }
//                        HStack {
//                            Text("Time: ".localized)
//                                .fontWeight(.semibold)
//                            Spacer()
//                            Text(course.timeDescription)
//                        }
                    }
                    .listStyle(.plain)
                    .scrollDisabled(true)
                }
                .hStackLeading()
                .padding()
            }
            .presentationDetents([.fraction(0.5)])
        }
    }
}

struct CurriculumWeekViewVerticalNew: View {
    var lectures: [Lecture]
    var _date: Date
    var currentSemesterName: String
    var weekNumber: Int?
    
    var date: Date {
        _date.startOfWeek()
    }
    
    @ViewBuilder
    func makeVStack(index: Int) -> some View {
        VStack {
            Text(daysOfWeek[index])
                .font(.system(.caption2, design: .monospaced, weight: .light))
//                .border(.red)
            
            ZStack(alignment: .top) {
                Color.clear
                
                ForEach(lectures.filter {(date.add(day: index) ... date.add(day: index + 1)).contains($0.startDate)}) { lecture in
                    LectureCardView(lecture: lecture)
                        .offset(y: Double((lecture.startIndex ?? 1) - 1) * heightPerClass + 2)
                        .padding(2)
                }
                
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 1)
                    .offset(y: 5 * heightPerClass + 1.5)
                    .opacity(0.5)
                
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 1)
                    .offset(y: 10 * heightPerClass + 1.5)
                    .opacity(0.5)
            }
//            .border(.blue)
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(0..<7) { index in
                        makeVStack(index: index)
                            .frame(width: geo.size.width / 7, height: heightPerClass * 13)
//                            .border(.black)
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
