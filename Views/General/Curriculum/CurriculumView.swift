//
//  CurriculumView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/19.
//

import SwiftUI

let heightPerClass = 60.0
let paddingWidth = 2.0

struct CurriculumSettingView: View {
    @AppStorage("curriculumShowSatAndSun") var showSatAndSun = false
    @AppStorage("semesterID", store: userDefaults) var semesterID = "301"

    @StateObject var curriculumDelegate = CurriculumDelegate.shared
    var courses: [Course] {
        curriculumDelegate.data
    }

    var status: AsyncViewStatus {
        curriculumDelegate.status
    }

    @Binding var date: Date
    @State var saveCalendarStatus: AsyncViewStatus? = nil
    var body: some View {
        NavigationStack {
            List {
                Toggle(isOn: $showSatAndSun) {
                    Label("Sat&Sun", systemImage: "lines.measurement.horizontal")
                }

                Picker(selection: $semesterID) {
                    ForEach(UstcUgAASClient.semesterIDList.sorted(by: { $0.value < $1.value }), id: \.key) { key, id in
                        Text(key)
                            .tag(id)
                    }
                } label: {
                    Label("Select time", systemImage: "square.3.stack.3d")
                }
                .onChange(of: semesterID) { _ in
                    curriculumDelegate.userTriggerRefresh()
                }

                DatePicker(selection: $date, displayedComponents: .date) {
                    Label("Pick a date", systemImage: "calendar")
                }

                Button {
                    Task {
                        saveCalendarStatus = .inProgress
                        do {
                            try await CurriculumDelegate.shared.saveToCalendar()
                            saveCalendarStatus = .success
                        } catch {
                            saveCalendarStatus = .failure
                        }
                    }
                } label: {
                    Label("Save to Calendar", systemImage: "square.and.arrow.down")
                        .asyncViewStatusMask(status: saveCalendarStatus)
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .navigationBarTitle("Settings", displayMode: .inline)
        }
        .presentationDetents([.fraction(0.4)])
    }
}

struct CurriculumView: View {
    @AppStorage("curriculumShowSatAndSun") var showSatAndSun = false
    @State var weekNumber = 0
    @State var date = Date()

    @StateObject var curriculumDelegate = CurriculumDelegate.shared
    var courses: [Course] {
        Course.filter(curriculumDelegate.data, week: weekNumber, weekday: nil)
    }

    var status: AsyncViewStatus {
        curriculumDelegate.status
    }

    @State var showSettingSheet = false

    func update(forceUpdate: Bool = false) {
        Task {
            weekNumber = UstcUgAASClient.shared.weekNumber(for: date)
        }
        curriculumDelegate.userTriggerRefresh(forced: forceUpdate)
    }

    var body: some View {
        mainView
            .padding(paddingWidth)
            .toolbar {
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
            .navigationTitle("Curriculum")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { update() }
            .refreshable { update(forceUpdate: true) }
            .onChange(of: date, perform: { _ in update() })
            .sheet(isPresented: $showSettingSheet) {
                CurriculumSettingView(date: $date)
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
                            .offset(y: Double(course.offset) * heightPerClass + 2)
                            .padding(2)
                    }
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
        }
    }

    var loadedView: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                Text("Week \(weekNumber)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Color.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(0 ..< 5) { index in
                            makeVStack(index: index)
                                .frame(width: geo.size.width / 5, height: heightPerClass * 13)
                        }
                        if showSatAndSun {
                            ForEach(5 ..< 7) { index in
                                makeVStack(index: index)
                                    .frame(width: geo.size.width / 5, height: heightPerClass * 13)
                            }
                        }
                    }
                }
                .scrollDisabled(!showSatAndSun)
            }
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

struct CurriculumView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CurriculumView()
        }

//        CurriculumSettingView(courses: .constant([]), status: .constant(.cached), date: .constant(Date()))
//            .previewDisplayName("Settings")
    }
}
