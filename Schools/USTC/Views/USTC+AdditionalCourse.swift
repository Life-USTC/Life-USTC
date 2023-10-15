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
                    USTCAdditionalCourseSemesterView(semester: semester)
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
    var semester: Semester

    @AppStorage("USTCAdditionalCourseIDList") var additioanlCourseIDList: [String: [Int]] = [:]

    var additionalCourseIDListForThisSemester: [Int]  {
        get {
            additioanlCourseIDList[semester.id] ?? []
        }
        set {
            additioanlCourseIDList[semester.id] = newValue
        }
    }

    @State var courses: [Course] = []
    @State var searchKeyword: String = ""

    var coursesToShow: [Course] {
        if searchKeyword.isEmpty {
            return courses
        } else {
            return courses.filter({ $0.name.contains(searchKeyword) })
        }
    }

    var body: some View {
        List {
            ForEach(coursesToShow) { course in
                Button {
                    if additionalCourseIDListForThisSemester.contains(course.id) {
                        additioanlCourseIDList[semester.id] = additionalCourseIDListForThisSemester.filter({ $0 != course.id })
                    } else {
                        additioanlCourseIDList[semester.id] = additionalCourseIDListForThisSemester + [course.id]
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            HStack(alignment: .bottom) {
                                Text(course.name)
                                Text(course.teacherName)
                                    .font(.caption)
                            }
                            .foregroundColor(.primary)

                            Text(course.courseCode)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if additionalCourseIDListForThisSemester.contains(course.id) {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }

            if coursesToShow.isEmpty {
                Text("No course found?")
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            Task {
                let url = URL(string: "https://static.xzkd.online/curriculum/\(semester.id)/courses.json")
                let (data, _) = try await URLSession.shared.data(from: url!)

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970
                courses = try! decoder.decode([Course].self, from: data)
            }
        }
        .searchable(text: $searchKeyword)
        .navigationTitle(semester.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
