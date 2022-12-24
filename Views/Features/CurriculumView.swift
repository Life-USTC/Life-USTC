//
//  UstcUgTable.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/19.
//

import SwiftUI

struct Course: Identifiable {
    var id = UUID()
    var dayOfWeek: Int
    var startTime: Int
    var endTime: Int
    var name: String
    var classIDString: String
    var classPositionString: String
    var classTeacherName: String
    var weekString: String
}

private let heightPerClass = 60.0
private let paddingWidth = 2.0
private let stackWidth = (UIScreen.main.bounds.width - paddingWidth * 2) / 5

// lazy version...
let classStartTimes: [DateComponents] =
[.init(hour: 7, minute: 50),
 .init(hour: 8, minute: 40),
 .init(hour: 9, minute: 45),
 .init(hour: 10, minute: 35),
 .init(hour: 11, minute: 25),
 .init(hour: 14, minute: 0),
 .init(hour: 14, minute: 50),
 .init(hour: 15, minute: 55),
 .init(hour: 16, minute: 45),
 .init(hour: 17, minute: 35),
 .init(hour: 19, minute: 30),
 .init(hour: 20, minute: 20),
 .init(hour: 21, minute: 10)]

let classEndTimes: [DateComponents] =
[.init(hour: 8, minute: 35),
 .init(hour: 9, minute: 25),
 .init(hour: 10, minute: 30),
 .init(hour: 11, minute: 20),
 .init(hour: 12, minute: 10),
 .init(hour: 14, minute: 45),
 .init(hour: 15, minute: 35),
 .init(hour: 16, minute: 40),
 .init(hour: 17, minute: 30),
 .init(hour: 18, minute: 20),
 .init(hour: 20, minute: 15),
 .init(hour: 21, minute: 5),
 .init(hour: 21, minute: 55)]

extension DateComponents {
    var clockTime: String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .none
        return dateFormatter.string(from: Date().stripTime() + self)
    }
}

struct CourseCardView: View {
    var course: Course
    @State var showPopUp = false
    
    var body: some View {
        VStack {
            Text(classStartTimes[course.startTime - 1].clockTime)
            Spacer()
            
            Text(course.name)
                .lineLimit(nil)
            Text(course.classPositionString)
            if course.startTime != course.endTime  {
                Divider()
                Text(course.classIDString)
                Text(course.classTeacherName)
                
                Spacer()
                Text(classEndTimes[course.endTime - 1].clockTime)
            }
        }
        .lineLimit(1)
        .font(.system(size: 12))
        .padding(4)
        .frame(height: heightPerClass * Double(course.endTime - course.startTime + 1))
        .background {
            RoundedRectangle(cornerRadius: 8)
                .stroke(showPopUp ? Color.accentColor : Color.gray, lineWidth: 1)
                .frame(width: stackWidth)
        }
        .onLongPressGesture(minimumDuration: 0.6) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            showPopUp = true
        }
        .sheet(isPresented: $showPopUp) {
            NavigationStack {
                VStack(alignment: .leading) {
                    Text(course.name)
                        .font(.title)
                    Text(classStartTimes[course.startTime - 1].clockTime + " - " + classEndTimes[course.endTime - 1].clockTime)
                        .bold()
                    
                    List {
                        Text("Location: \(course.classPositionString)")
                        Text("Teacher: \(course.classTeacherName)")
                        Text("ID: \(course.classIDString)")
                        Text("Week: \(course.weekString)")
                    }
                    .listStyle(.plain)
                    .scrollDisabled(true)
                }
                .hStackLeading()
                .padding()
            }
            .presentationDetents([.fraction(0.4)])
        }
    }
}

struct CurriculumView: View {
    @State var showSatAndSun = false
    @State var courses: [Course] = []
    @State var status: AsyncViewStatus = .inProgress
    
    var body: some View {
        NavigationStack {
            mainView
                .padding(paddingWidth)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            withAnimation {
                                showSatAndSun.toggle()
                            }
                        } label: {
                            Text("Sat&Sun")
                        }
                        
                        Button {
                            withAnimation {
                                showSatAndSun.toggle()
                            }
                        } label: {
                            Text("Sat&Sun")
                        }
                    }
                }
                .navigationTitle("Curriculum")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    mainUstcUgAASClient.getCurriculum(courses: $courses, status: $status)
                }
        }
    }
    
    func makeVStack(index: Int) -> some View {
        VStack {
            Text(daysOfWeek[index])
            ZStack(alignment: .top) {
                Color.clear
                
                ForEach(courses) { course in
                    if course.dayOfWeek == (index + 1) {
                        CourseCardView(course: course)
                            .offset(y: Double(course.startTime - 1) * heightPerClass)
                    }
                }
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.accentColor)
                    .offset(y: 5 * heightPerClass)
                    .opacity(0.5)
                
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.accentColor)
                    .offset(y: 10 * heightPerClass)
                    .opacity(0.5)
            }
        }
        .frame(width: stackWidth, height: heightPerClass * 13)
    }
    
    var loadedView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(0..<5) { index in
                        makeVStack(index: index)
                    }
                    if showSatAndSun {
                        ForEach(5..<7) { index in
                            makeVStack(index: index)
                        }
                    }
                }
            }
            .scrollDisabled(!showSatAndSun)
        }
    }
    
    var mainView: some View {
        Group {
            if status == .inProgress {
                ProgressView()
            } else {
                loadedView
            }
        }
    }
}

struct CurriculumPreview: View {
    @State var courses: [Course] = []
    @State var status: AsyncViewStatus = .inProgress
    var todayCourse: [Course] {
        courses.filter({ course in
            return course.dayOfWeek == Calendar.current.component(.weekday, from: Date())
        })
    }
    
    var body: some View {
        Group {
            if status == .inProgress {
                ProgressView()
            } else {
                if todayCourse.isEmpty {
                    happyView
                } else {
                    mainView
                }
            }
        }.onAppear {
            mainUstcUgAASClient.getCurriculum(courses: $courses, status: $status)
        }
    }
    
    var mainView: some View {
        List {
            ForEach(todayCourse) { course in
                HStack {
                    TitleAndSubTitle(title: course.name, subTitle: course.classPositionString, style: .substring)
                    Spacer()
                    Text(classStartTimes[course.startTime - 1].clockTime + " - " + classEndTimes[course.endTime - 1].clockTime)
                }
            }
        }
        .listStyle(.plain)
    }
    
    var happyView: some View {
        VStack {
            Image(systemName: "signature")
                .foregroundColor(.accentColor)
                .font(.system(size: 40))
            
            Text("Free today!")
        }
    }
}

