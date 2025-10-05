//
//  USTC+AdditionalCourse.swift
//  学在科大
//
//  Created by Tiankai Ma on 2023/10/15.
//

import SwiftUI
import SwiftyJSON

private let curriculumDataURL = URL(
    string: "\(staticURLPrefix)/curriculum/"
)

struct USTCAdditionalCourseView: View {
    @State var semesters: [Semester] = []

    var body: some View {
        List {
            Section {
                ForEach(semesters) { semester in
                    NavigationLink {
                        USTCAdditionalCourseSemesterView(semester: semester)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(semester.name)
                                .if((semester.startDate ... semester.endDate).contains(Date())) {
                                    $0.foregroundColor(.accentColor)
                                }
                            HStack {
                                Text(
                                    DateFormatter.localizedString(
                                        from: semester.startDate,
                                        dateStyle: .short,
                                        timeStyle: .none
                                    )
                                )
                                Text("-")
                                Text(
                                    DateFormatter.localizedString(
                                        from: semester.endDate,
                                        dateStyle: .short,
                                        timeStyle: .none
                                    )
                                )
                            }
                            .font(.system(.caption, design: .monospaced))
                            .bold((semester.startDate ... semester.endDate).contains(Date()))
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text(
                    "You can choose additional courses here, they would appear in your curriculum alongside other alongside other courses. This is useful for sit-in or TA courses"
                )
            }
        }
        .task {
            Task {
                let url = URL(string: "\(staticURLPrefix)/curriculum/semesters.json")
                let (data, _) = try await URLSession.shared.data(from: url!)

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970
                semesters = try decoder.decode([Semester].self, from: data).sorted(by: { $0.startDate > $1.startDate })
            }
        }
        .navigationTitle("Select Additional Course")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct USTCAdditionalCourseSemesterView: View {
    var semester: Semester

    @AppStorage("USTCAdditionalCourseIDList") var additioanlCourseIDList: [String: [Int]] = [:]

    var additionalCourseIDListForThisSemester: [Int] {
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
        guard searchKeyword.isEmpty else {
            return courses.filter({
                $0.name.contains(searchKeyword)
                    || $0.teacherName.contains(searchKeyword)
                    || $0.courseCode.contains(searchKeyword)
                    || $0.lessonCode.contains(searchKeyword)
            })
        }
        return courses
    }

    var body: some View {
        List {
            ForEach(coursesToShow) { course in
                Button {
                    if additionalCourseIDListForThisSemester.contains(course.id) {
                        additioanlCourseIDList[semester.id] = additionalCourseIDListForThisSemester.filter({
                            $0 != course.id
                        })
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

                            Text(course.lessonCode)
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
                let url = URL(string: "\(staticURLPrefix)/curriculum/\(semester.id)/courses.json")
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
