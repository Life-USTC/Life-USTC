//
//  USTC+AdditionalCourse.swift
//  学在科大
//
//  Created by Tiankai Ma on 2023/10/15.
//

import SwiftUI
import SwiftyJSON

fileprivate let curriculumDataURL = URL(
    string: "https://static.xzkd.online/curriculum/"
)

struct USTCAdditionalCourseView: View {
    @State var semesters: [Semester] = []

    var body: some View {
        List {
            ForEach(semesters) { semester in
                NavigationLink {
                    USTCAdditionalCourseSemesterView(semesterID: semester.id)
                } label: {
                    VStack(alignment: .leading) {
                        Text(semester.name)
                        Text(semester.startDate ... semester.endDate)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task {
            Task {
                let url = URL(string: "https://static.xzkd.online/curriculum/semesters.json")
                let (data, _) = try await URLSession.shared.data(from: url!)

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970
                semesters = try decoder.decode([Semester].self, from: data).sorted(by: { $0.startDate > $1.startDate })
            }
        }
        .navigationTitle("Additional Course")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct USTCAdditionalCourseSemesterView: View {
    var semesterID: String

    @AppStorage("USTCAdditionalCourseIDList") var additioanlCourseIDList: [Int] = []
    @State var courses: [Course] = []

    var body: some View {
        List {
            ForEach(courses) { course in
                HStack {
                    VStack(alignment: .leading) {
                        HStack(alignment: .bottom) {
                            Text(course.name)
                            Text(course.teacherName)
                                .font(.caption)
                        }
                        Text(course.courseCode)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if additioanlCourseIDList.contains(course.id) {
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
                .onTapGesture {
                    if additioanlCourseIDList.contains(course.id) {
                        additioanlCourseIDList.removeAll { $0 == course.id }
                    } else {
                        additioanlCourseIDList.append(course.id)
                    }
                }
            }
        }
        .task {
            Task {
                let url = URL(string: "https://static.xzkd.online/curriculum/\(semesterID)/courses.json")
                let (data, _) = try await URLSession.shared.data(from: url!)

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970
                courses = try! decoder.decode([Course].self, from: data)
            }
        }
    }
}
