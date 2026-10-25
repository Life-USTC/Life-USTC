//
//  USTC+AdditionalCourse.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/10/15.
//

import SwiftUI

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
                                .if(semester.isCurrent) {
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
                            .bold(semester.isCurrent)
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
                semesters = try await USTCStaticService().fetchSemesters()
                    .map { item in
                        Semester(
                            jw_id: item.id,
                            name: item.name,
                            startDate: Date(timeIntervalSince1970: item.startDate),
                            endDate: Date(timeIntervalSince1970: item.endDate)
                        )
                    }
                    .sorted(by: { $0.startDate > $1.startDate })
            }
        }
        .navigationTitle("Select Additional Course")
    }
}

struct USTCAdditionalCourseSemesterView: View {
    var semester: Semester

    @AppStorage("USTCAdditionalCourseIDList") var additioanlCourseIDList: [String: [Int]] = [:]

    var additionalCourseIDListForThisSemester: [Int] {
        get {
            additioanlCourseIDList[semester.jw_id] ?? []
        }
        set {
            additioanlCourseIDList[semester.jw_id] = newValue
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
                    if additionalCourseIDListForThisSemester.contains(course.jw_id) {
                        additioanlCourseIDList[semester.jw_id] = additionalCourseIDListForThisSemester.filter({
                            $0 != course.jw_id
                        })
                    } else {
                        additioanlCourseIDList[semester.jw_id] = additionalCourseIDListForThisSemester + [course.jw_id]
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

                        if additionalCourseIDListForThisSemester.contains(course.jw_id) {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }

            if coursesToShow.isEmpty {
                ContentUnavailableView(
                    "No Course Found",
                    systemImage: "book.closed"
                )
            }
        }
        .navigationTitle(semester.name)
        .task {
            try? await updateCourses()
        }
        .refreshable {
            Task {
                try await updateCourses()
            }
        }
        .searchable(text: $searchKeyword, placement: .navigationBarDrawer(displayMode: .always))
    }

    func updateCourses() async throws {
        let items = try await USTCStaticService().fetchCourseList(semesterId: semester.jw_id)
        courses = items.map { item in
            Course(
                jw_id: item.id,
                name: item.name,
                courseCode: item.courseCode,
                lessonCode: item.lessonCode,
                teacherName: item.teacherName,
            )
        }
    }
}
