//
//  SingleExamView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/9.
//

import SwiftUI

struct SingleExamView: View {
    let exam: Exam

    var basicInfoView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                Text("\(exam.courseName)")
                    .font(.system(.title2, weight: .bold))
                    .strikethrough(exam.isFinished)
                    .foregroundColor(exam.isFinished ? .gray : .primary)

                Text("\(exam.lessonCode)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text("\(exam.typeName)")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }

    var timeInfoView: some View {
        if exam.isFinished {
            Text("Finished".localized)
                .fontWeight(.bold)
                .foregroundColor(.gray)
        } else {
            Text(exam.startDate, style: .relative)
                .fontWeight(.bold)
                .foregroundColor(
                    exam.daysLeft <= 7 ? .red : .accentColor
                )
        }
    }

    var detailView: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Image(systemName: "location.fill.viewfinder")
                    Text(exam.detailLocation)
                }

                HStack(alignment: .top) {
                    Image(systemName: "calendar.badge.clock")
                    VStack(alignment: .leading) {
                        Text(exam.startDate, style: .date)
                        Text(exam.startDate ... exam.endDate)
                    }
                    Spacer()
                }
            }
            .font(.callout)

            timeInfoView
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            basicInfoView
            detailView
        }
    }
}
