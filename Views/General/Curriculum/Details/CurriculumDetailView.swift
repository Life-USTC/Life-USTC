//
//  CurriculumDetailView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/19.
//

import SwiftUI

struct CurriculumDetailView: View {
    @ManagedData(.curriculum) var curriculum: Curriculum

    var body: some View {
        List {
            Section {

            } header: {
                AsyncStatusLight(status: _curriculum.status)
            }

            ForEach(curriculum.semesters) { semester in
                Section(header: Text(semester.name)) {
                    ForEach(semester.courses, id: \.lessonCode) { course in
                        NavigationLink {
                            CourseDetailView(course: course)
                        } label: {
                            Text(course.name)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .asyncStatusOverlay(_curriculum.status, showLight: false)
        .refreshable { _curriculum.triggerRefresh() }
        .navigationTitle("Curriculum").navigationBarTitleDisplayMode(.inline)
    }
}
