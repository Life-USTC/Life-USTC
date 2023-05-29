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
    @State var status: AsyncViewStatus = .inProgress
    @State var navigationToSettingsView = false
    @State private var datePickerShown = false

    func update(with date: Date) {
        Task {
            weekNumber = await UstcUgAASClient.shared.weekNumber(for: date)
            CurriculumDelegate.shared.asyncBind(status: $status) {
                courses = Course.filter($0, week: weekNumber, for: date)
                tomorrow_course = Course.filter($0, week: weekNumber, for: date.add(day: 1))
            }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            // MARK: - Curriculum

            VStack(alignment: .leading) {
                HStack(spacing: 0) {
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

                VStack(alignment: .leading) {
                    Text("Today")
                        .font(.headline)
                        .foregroundColor(Color.secondary)
                    CourseStackView(courses: $courses)
                }

                Spacer(minLength: 30)

                VStack(alignment: .leading) {
                    Text("Tomorrow")
                        .font(.headline)
                        .foregroundColor(Color.secondary)
                    CourseStackView(courses: $tomorrow_course)
                }
            }

            Spacer(minLength: 30)

            // MARK: - Exams

            VStack(alignment: .leading) {
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

                ExamPreview()
            }
        }
        .padding(.horizontal)
        .navigationTitle("Life@USTC")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { update(with: Date()) }
        .refreshable { update(with: date) }
        .onChange(of: date, perform: update)
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
