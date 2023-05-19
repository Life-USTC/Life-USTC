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
    @State var navigationToCurriculumView = false
    @State var navigationToSettingsView = false

    func update(with date: Date) {
        Task {
            weekNumber = await UstcUgAASClient.shared.weekNumber(for: date)
            CurriculumDelegate.shared.asyncBind(status: $status) {
                self.courses = Course.filter($0, week: weekNumber, for: date)
                self.tomorrow_course = Course.filter($0, week: weekNumber, for: date.add(day: 1))
            }
        }
    }

    var body: some View {
        ScrollView {
            // MARK: - Curriculum

            VStack(alignment: .leading) {
                HStack (spacing:0){
                    Text("Curriculum")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.vertical, 2)
                        .onLongPressGesture {
                            navigationToCurriculumView.toggle()
                        }
                        .navigationDestination(isPresented: $navigationToCurriculumView) {
                            CurriculumView()
                        }

                    Spacer()
                    Text("Week \(weekNumber)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Color.secondary)
                    DatePicker(selection: $date, displayedComponents: .date) {}
                        .frame(width: 137, height: 35, alignment: .center)
                        .clipped()
                }
                VStack (alignment: .leading) {
                    Text("Today")
                        .font(.headline)
                        .foregroundColor(Color.secondary)
                    CourseStackView(courses: $courses)
                }

                Spacer(minLength: 30)

                VStack (alignment: .leading) {
                    Text("Tomorrow")
                        .font(.headline)
                        .foregroundColor(Color.secondary)
                    CourseStackView(courses: $tomorrow_course)
                }
            }

            Spacer(minLength: 30)

            // MARK: - Exams

            VStack(alignment: .leading) {
                Text("Exams")
                    .font(.title2)
                    .fontWeight(.bold)
                    .hStackLeading()
                    .padding(.bottom, 2)

                ExamPreview()
            }
        }
        .padding(.horizontal)
        .navigationTitle("Life@USTC")
        .onAppear {
            update(with: Date())
        }
        .onChange(of: date, perform: update)
        .toolbar {
            Button {
                navigationToSettingsView.toggle()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .navigationDestination(isPresented: $navigationToSettingsView) {
            SettingsView()
                .navigationBarTitleDisplayMode(.inline)
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
