//
//  LectureItemView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import SwiftUI

struct LectureView: View {
    var lecture: Lecture
    var color: Color = .red

    var lectureColor: Color {
        (lecture.course?.color() ?? color).opacity(0.8)
    }

    var isCompleted: Bool {
        lecture.endDate < Date()
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(lecture.name)
                    .font(.headline)
                    .fontWeight(.bold)
                Text("\(lecture.teacherName) @ **\(lecture.location)**")
                    .font(.footnote)
                    .foregroundColor(.gray.opacity(0.8))
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(lecture.startDate.stripHMwithTimezone())
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.mint)
                Text(lecture.endDate.stripHMwithTimezone())
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.8))
            }
        }
        .padding(.leading, 15)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .background {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(lectureColor)
                    .frame(width: 5)
                RoundedCornersShape(corners: [.topRight, .bottomRight], radius: 5)
                    .fill(lectureColor.opacity(0.05))
            }
        }
        .if(isCompleted) {
            $0
                .strikethrough()
                .grayscale(1.0)
        }
        .if(lecture != Lecture.example) {
            $0.lectureSheet(lecture: lecture)
        }
    }
}
