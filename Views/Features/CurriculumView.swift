//
//  CurriculumView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/19.
//

import SwiftUI

private let heightPerClass = 60.0
private let paddingWidth = 2.0
private let stackWidth = (UIScreen.main.bounds.width - paddingWidth * 2) / 5

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
            if course.startTime != course.endTime {
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
    @AppStorage("curriculmShowSatAndSun") var showSatAndSun = false
    @AppStorage("semesterID") var semesterID = "281"
    @State var courses: [Course] = []
    @State var status: AsyncViewStatus = .inProgress
    @State var showSettingSheet = false

    var settingSheet: some View {
        NavigationStack {
            List {
                Toggle("Sat&Sun", isOn: $showSatAndSun)

                HStack {
                    Text("Select time")
                    Spacer()
                    Menu {
                        ForEach(UstcUgAASClient.semesterIDList.sorted(by: { $0.value < $1.value }), id: \.key) { key, id in
                            Button {
                                semesterID = id
                                UstcUgAASClient.main.semesterID = semesterID
                                asyncBind($courses, status: $status) {
                                    try await UstcUgAASClient.main.forceUpdate()
                                    return try await UstcUgAASClient.main.getCurriculum()
                                }
                            } label: {
                                if semesterID == id {
                                    HStack {
                                        Text(key)
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                Text(key)
                            }
                        }
                    } label: {
                        Text(UstcUgAASClient.semesterIDList.first(where: { $0.value == semesterID })?.key ?? "")
                    }
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.fraction(0.4)])
    }

    var body: some View {
        NavigationStack {
            mainView
                .padding(paddingWidth)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        if status == .inProgress {
                            ProgressView()
                        }
                        Button {
                            withAnimation {
                                showSettingSheet.toggle()
                            }
                        } label: {
                            Label("Show settings", systemImage: "gearshape")
                        }
                    }
                }
                .navigationTitle("Curriculum")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    asyncBind($courses, status: $status) {
                        return try await UstcUgAASClient.main.getCurriculum()
                    }
                }
                .sheet(isPresented: $showSettingSheet) {
                    settingSheet
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
                    ForEach(0 ..< 5) { index in
                        makeVStack(index: index)
                    }
                    if showSatAndSun {
                        ForEach(5 ..< 7) { index in
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
        courses.filter { course in
            course.dayOfWeek == currentWeekDay
        }
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
        }
        .frame(width: cardWidth)
        .onAppear {
            asyncBind($courses, status: $status) {
                return try await UstcUgAASClient.main.getCurriculum()
            }
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
        .frame(height: cardHeight / 3 * Double(todayCourse.count))
    }

    /// If no class are shown...
    var happyView: some View {
        VStack {
            Image(systemName: "signature")
                .foregroundColor(.accentColor)
                .font(.system(size: 40))
            Text("Free today!")
        }
    }
}
