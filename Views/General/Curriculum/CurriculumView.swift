//
//  CurriculumView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/19.
//

import SwiftUI

let heightPerClass = 60.0
let paddingWidth = 2.0
let stackWidth = (UIScreen.main.bounds.width - paddingWidth * 2) / 5

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
                        try await UstcUgAASClient.main.getCurriculum()
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
