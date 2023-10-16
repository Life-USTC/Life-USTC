//
//  LectureDetailView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/19.
//

import SwiftUI

struct LectureDetailView: View {
    let lecture: Lecture
    var body: some View {
        List {
            HStack {
                Text("Name")
                Spacer()
                Text(lecture.name)
            }

            HStack {
                Text("Location")
                Spacer()
                Text(lecture.location)
            }

            HStack {
                Text("Teacher")
                Spacer()
                Text(lecture.teacherName)
            }

            HStack {
                Text("Periods")
                Spacer()
                Text("\(lecture.periods)")
            }

            HStack {
                Text("Start Date")
                Spacer()
                Text("\(lecture.startDate.description(with: .current))")
            }

            HStack {
                Text("End Date")
                Spacer()
                Text("\(lecture.endDate.description(with: .current))")
            }

            ForEach(lecture.additionalInfo.sorted(by: <), id: \.key) {
                key,
                value in
                HStack {
                    Text(key)
                    Spacer()
                    Text(value)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}
