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
    @Binding var courses: [Course]
    @Binding var status: AsyncViewStatus
    @State var saveCalendarStatus = AsyncViewStatus.inProgress
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
                    asyncBind($courses, status: $status) {
                        try await CurriculumDelegate.shared.forceUpdate()
                        return try await CurriculumDelegate.shared.parseCache()
                    }
                }

                Button {
                    asyncBind(.constant(()), status: $saveCalendarStatus) {
                        try await CurriculumDelegate.shared.saveToCalendar()
                    }
                } label: {
                    HStack {
                        Label("Save to Calendar", systemImage: "square.and.arrow.down")
                        Spacer()
                        if saveCalendarStatus == .success {
                            HStack {
                                Text("Saved")
                                Image(systemName: "checkmark.seal")
                            }
                            .foregroundColor(.accentColor)
                        }
                        if saveCalendarStatus == .failure {
                            HStack {
                                Text("Something went wrong")
                                Image(systemName: "questionmark.diamond.fill")
                            }
                            .foregroundColor(.red)
                        }
                    }
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
    @State var courses: [Course] = []
    @State var status: AsyncViewStatus = .inProgress
    @State var showSettingSheet = false

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
            .navigationBarTitle("Curriculum", displayMode: .inline)
            .task {
                CurriculumDelegate.shared.asyncBind($courses, status: $status)
            }
            .sheet(isPresented: $showSettingSheet) {
                CurriculumSettingView(courses: $courses, status: $status)
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
                            .offset(y: Double(course.startTime - 1) * heightPerClass + 2)
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

        CurriculumSettingView(courses: .constant([]), status: .constant(.cached))
            .previewDisplayName("Settings")
    }
}
