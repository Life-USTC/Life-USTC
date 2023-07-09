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

struct HomeView<CurriculumDelegate: CurriculumDelegateProtocol,
    ExamDelegate: ExamDelegateProtocol>: View
{
    @State var date = Date()
    @ObservedObject var curriculumDelegate: CurriculumDelegate
    @ObservedObject var examDelegate: ExamDelegate

    @ObservedObject var ustcCasClient = UstcCasClient.shared
    @ObservedObject var ustcUgAASClient = UstcUgAASClient.shared

    @State var navigationToSettingsView = false
    @State private var datePickerShown = false

    var today_courses: [Course] {
        curriculumDelegate.data.getCourses(for: date)
    }

    var tomorrow_courses: [Course] {
        curriculumDelegate.data.getCourses(for: date.add(day: 1))
    }

    var weekNumber: Int {
        curriculumDelegate.data.weekNumber(for: date)
    }

    var curriculumStatus: AsyncViewStatus {
        curriculumDelegate.status
    }

    var exams: [Exam] {
        examDelegate.data
    }

    var examStatus: AsyncViewStatus {
        examDelegate.status
    }

    var mmddFormatter: DateFormatter {
        let tmp = DateFormatter()
        tmp.dateStyle = .short
        tmp.timeStyle = .none
        return tmp
    }

    func update(forceUpdate: Bool = false) {
        curriculumDelegate.userTriggerRefresh(forced: forceUpdate)
        examDelegate.userTriggerRefresh(forced: forceUpdate)
    }

    var delegateHelperView: some View {
        HStack {
            Button {
                Task {
                    try await ustcCasClient.loginToCAS()
                }
            } label: {
                VStack {
                    Text("CAS Client")
                    Text(ustcCasClient.lastLogined?.debugDescription ?? "nil")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(lineWidth: 1)
                }
            }

            Button {
                Task {
                    try await ustcUgAASClient.login()
                }
            } label: {
                VStack {
                    Text("Ug AAS Client")
                    Text(ustcUgAASClient.lastLogined?.debugDescription ?? "nil")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(lineWidth: 1)
                }
            }
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
#if DEBUG
            delegateHelperView
#endif

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
                        SharedCurriculumView
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }

                curriculumView
                    .asyncViewStatusMask(status: curriculumStatus)
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
                        SharedExamView
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }

                ExamPreview(exams: examDelegate.data)
                    .asyncViewStatusMask(status: examStatus)
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
            SharedHomeView
        }
    }
}
