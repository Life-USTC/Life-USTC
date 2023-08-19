//
//  CurriculumView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/19.
//

import SwiftUI

struct CurriculumView: View {
    @ManagedData(\.curriculum) var curriculum: Curriculum!
    @State var status: AsyncStatus?

    var body: some View {
        List {
            ForEach(curriculum.semesters.sorted(by: { $0.startDate > $1.startDate })) { semester in
                Section(header: Text(semester.name)) {
                    ForEach(semester.courses, id: \.code) { course in
                        NavigationLink(destination: CourseView(course: course)) {
                            Text(course.name)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .asyncStatusMask(status: status)
        .refreshable {
            _curriculum.userTriggeredRefresh()
        }
        .onReceive(_curriculum.$status, perform: {
            status = $0
        })
        .padding(.horizontal)
        .navigationTitle("Curriculum")
        .navigationBarTitleDisplayMode(.inline)
    }
}
