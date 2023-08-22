//
//  CurriculumDetailView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/19.
//

import SwiftUI

struct CurriculumDetailView: View {
    @ManagedData(.curriculum) var curriculum: Curriculum!

    var body: some View {
        List {
            if let curriculum {
                ForEach(curriculum.semesters) { semester in
                    Section(header: Text(semester.name)) {
                        ForEach(semester.courses, id: \.lessonCode) { course in
                            NavigationLink(destination: CourseDetailView(course: course)) {
                                Text(course.name)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .asyncStatusMask(status: _curriculum.status)
        .refreshable {
            _curriculum.triggerRefresh()
        }
        .navigationTitle("Curriculum")
        .navigationBarTitleDisplayMode(.inline)
    }
}
