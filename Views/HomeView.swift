//
//  HomeView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/15.
//

import SwiftUI

private struct HomeFeature {
    var title: String
    var subTitle: String
    var destination: AnyView
    var preview: AnyView
}

struct HomeView: View {
    @State var weekNumber = 0
    @State var date = Date()
    @State var courses: [Course] = []
    @State var tomorrow_course: [Course] = []
    @State var exams: [Exam] = []
    @State var status: AsyncViewStatus = .inProgress
    @State var navigationToSettingsView = false
    @State private var datePickerShown = false

    var mmddFormatter: DateFormatter {
        let tmp = DateFormatter()
        tmp.dateStyle = .short
        tmp.timeStyle = .none
        return tmp
    }

    func update(forceUpdate: Bool = false) {
        Task {
            status = .inProgress
            courses = []
            tomorrow_course = []
            exams = []
            weekNumber = await UstcUgAASClient.shared.weekNumber(for: date)
            if forceUpdate {
                try await CurriculumDelegate.shared.forceUpdate()
                try await ExamDelegate.shared.forceUpdate()
            }
            CurriculumDelegate.shared.asyncBind(status: $status) {
                courses = Course.filter($0, week: weekNumber, for: date)
                tomorrow_course = Course.filter($0, week: weekNumber, for: date.add(day: 1))
            }
            ExamDelegate.shared.asyncBind($exams, status: $status)
        }
    }

    var curriculumView: some View {
        VStack {
            VStack(alignment: .leading) {
                if date.stripTime() == Date().stripTime() {
                    Text("Today")
                        .font(.headline)
                        .foregroundColor(Color.secondary)
                } else {
                    Text(mmddFormatter.string(from: date))
                        .font(.headline)
                        .foregroundColor(Color.secondary)
                }
                CourseStackView(courses: $courses)
            }

            Spacer(minLength: 30)

            VStack(alignment: .leading) {
                if date.stripTime() == Date().stripTime() {
                    Text("Tomorrow")
                        .font(.headline)
                        .foregroundColor(Color.secondary)
                } else {
                    Text(mmddFormatter.string(from: date.add(day: 1)))
                        .font(.headline)
                        .foregroundColor(Color.secondary)
                }
                CourseStackView(courses: $tomorrow_course)
            }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            // MARK: - Curriculum

            VStack {
                HStack {
                    Text("Curriculum")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.vertical, 2)

                    Spacer()

                    Text("Week \(weekNumber)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Color.secondary)
                        .padding(.horizontal)

                    NavigationLink {
                        CurriculumView()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }

                if status == .inProgress {
                    ProgressView()
                } else {
                    curriculumView
                }
            }

            Spacer(minLength: 30)

            // MARK: - Exams

            VStack {
                HStack {
                    Text("Exams")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.bottom, 2)

                    Spacer()

                    NavigationLink {
                        ExamView()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }

                if status == .inProgress {
                    ProgressView()
                } else {
                    ExamPreview(exams: exams)
                }
            }
        }
        .padding(.horizontal)
        .navigationTitle("Life@USTC")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { update() }
        .refreshable { update(forceUpdate: true) }
        .onChange(of: date, perform: { _ in update() })
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    navigationToSettingsView.toggle()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button {
                    datePickerShown = true
                } label: {
                    Label("Pick a date", systemImage: "calendar")
                }
            }
        }
        .sheet(isPresented: $datePickerShown) {
            DatePicker(
                "Choose date",
                selection: $date,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal)
            .presentationDetents([.fraction(0.45)])
        }
        .sheet(isPresented: $navigationToSettingsView) {
            NavigationStack {
                SettingsView()
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HomeView()
        }
    }
}
