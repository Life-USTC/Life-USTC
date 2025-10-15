//
//  SingleHomeworkView.swift
//  学在科大
//
//  Created by TianKai Ma on 10/15/25.
//

import SwiftUI

struct SingleHomeWorkView: View {
    let homework: Homework

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading) {
                Text(homework.title)
                    .font(.system(.title2, weight: .bold))
                    .strikethrough(homework.isFinished)
                    .foregroundColor(homework.isFinished ? .gray : .primary)

                Text(homework.courseName)
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Spacer(minLength: 25)

                HStack {
                    Image(systemName: "calendar.badge.clock")
                    Text(homework.dueDate, style: .date)
                    Text(homework.dueDate, style: .time)
                }
                .font(.callout)
            }

            Spacer()

            if homework.isFinished {
                Text("Finished".localized)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)

            } else {
                Text(homework.dueDate, style: .relative)
                    .fontWeight(.bold)
                    .foregroundColor(
                        homework.daysLeft <= 1 ? .red : .accentColor
                    )
            }
        }
        .padding(.vertical, 2)
    }
}
