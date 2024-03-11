//
//  CourseDetailView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/19.
//

import SwiftUI

struct CourseDetailView: View {
    let course: Course
    var body: some View {
        List {
            HStack {
                Text("Name")
                Spacer()
                Text(course.name)
            }

            HStack {
                Text("Code")
                Spacer()
                Text(course.lessonCode)
            }

            HStack {
                Text("Teacher")
                Spacer()
                Text(course.teacherName)
            }

            HStack {
                Text("Credit")
                Spacer()
                Text("\(course.credit)")
            }

            if let description = course.description {
                HStack {
                    Text("Description")
                    Spacer()
                    Text(description)
                }
            }

            ForEach(
                course.additionalInfo.sorted(by: { $0.key < $1.key }),
                id: \.key
            ) { key, value in
                HStack {
                    Text(key)
                    Spacer()
                    Text(value)
                }
            }

            Section {
                ForEach(course.lectures) { lecture in
                    NavigationLink(
                        destination: LectureDetailView(lecture: lecture)
                    ) {
                        Text(lecture.name)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}
