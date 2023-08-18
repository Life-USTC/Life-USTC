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
    @State var date = Date()
//    @ObservedObject var examDelegate: ExamDelegate

    @State var navigationToSettingsView = false
    @State private var datePickerShown = false

    var today_courses: [Course] {
//        curriculumDelegate.data.getCourses(for: date)
        []
    }

    var tomorrow_courses: [Course] {
//        curriculumDelegate.data.getCourses(for: date.add(day: 1))
        []
    }

    var weekNumber: Int {
//        curriculumDelegate.data.weekNumber(for: date)
        0
    }

//    var curriculumStatus: AsyncViewStatus {
    ////        curriculumDelegate.status
//        .cached
//    }

    var exams: [Exam] {
//        examDelegate.data
        []
    }

//    var examStatus: AsyncViewStatus {
    ////        examDelegate.status
//        .cached
//    }

    var mmddFormatter: DateFormatter {
        let tmp = DateFormatter()
        tmp.dateStyle = .short
        tmp.timeStyle = .none
        return tmp
    }

    func update(forceUpdate _: Bool = false) {
//        curriculumDelegate.userTriggerRefresh(forced: forceUpdate)
//        examDelegate.userTriggerRefresh(forced: forceUpdate)
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
                CourseStackView(courses: today_courses)
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
                CourseStackView(courses: tomorrow_courses)
            }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            InAppNotificationTabView()
                .padding(.bottom, 5)

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
//                        SharedCurriculumView
                        CurriculumView()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }

                curriculumView
//                    .asyncViewStatusMask(status: curriculumStatus)
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
//                        SharedExamView
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }

//                ExamPreview(exams: examDelegate.data)
//                    .asyncViewStatusMask(status: examStatus)
            }

            Spacer()
                .frame(height: 70)
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
//            SharedHomeView
        }
    }
}
