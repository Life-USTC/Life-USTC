//
//  SingleExamView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/9.
//

import SwiftUI

struct SingleExamView: View {
    let exam: Exam

    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            VStack(alignment: .leading) {
                HStack(alignment: .center) {
                    Text("\(exam.courseName)").font(.title2).fontWeight(.bold)
                        .strikethrough(exam.isFinished)
                    Spacer()
                    Text("\(exam.typeName)").foregroundColor(Color.gray).font(
                        .subheadline
                    )
                }
                Text("\(exam.lessonCode)").foregroundColor(Color.gray).font(
                    .subheadline
                )
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Image(systemName: "location.fill.viewfinder")
                    Text(
                        "\(exam.classRoomDistrict) \(exam.classRoomBuildingName) \(exam.classRoomName)"
                    )
                }.font(.callout)
                HStack {
                    Image(systemName: "calendar.badge.clock")
                    Text(exam.detailString)
                    Spacer()
                    if exam.isFinished {
                        Text("Finished".localized).foregroundColor(.gray)
                            .fontWeight(.bold)
                    } else {
                        Text(
                            exam.daysLeft == 1
                                ? "1 day left".localized
                                : String(
                                    format: "%@ days left".localized,
                                    String(exam.daysLeft)
                                )
                        ).foregroundColor(
                            exam.daysLeft <= 7 ? .red : .accentColor
                        ).fontWeight(.bold)
                    }
                }.font(.callout)
            }
        }
    }
}
