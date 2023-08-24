//
//  SingleScoreView.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/7.
//

import SwiftUI

struct SingleScoreView: View {
    var courseScore: CourseScore
    var color: Color

    var noScoreView: some View {
        Image(systemName: "xmark")
            .font(.body)
            .foregroundColor(.white)
            .padding(4)
            .frame(width: 85, height: 30)
            .background(
                Stripes(
                    config: .init(
                        background: .gray,
                        foreground: .white.opacity(0.4)
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 5))
            )
    }

    var noGPAView: some View {
        Text("\(String(courseScore.score))")
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(4)
            .frame(width: 85, height: 30)
            .background(
                Stripes(
                    config: .init(
                        background: .cyan,
                        foreground: .white.opacity(0.4)
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 5))
            )
    }

    var normalView: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("\(courseScore.score)")
                .frame(width: 35)
                .padding(.horizontal, 4)
            Divider()
            Text("\(String(courseScore.gpa!))")
                .frame(width: 35)
                .padding(.horizontal, 4)
        }
        .fontWeight(.bold)
        .foregroundColor(.white)
        .frame(width: 85, height: 30)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(color)
        )
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(courseScore.courseName)
                    .fontWeight(.bold)
                HStack {
                    Text(String(courseScore.credit))
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    Text(courseScore.courseCode)
                        .foregroundColor(.gray)
                }
                .font(.subheadline)
            }

            Spacer()

            if courseScore.gpa == nil {
                if courseScore.score.isEmpty {
                    noScoreView
                } else {
                    noGPAView
                }
            } else {
                normalView
            }
        }
    }
}

struct SingleScoreView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .trailing) {
            SingleScoreView(courseScore: .example, color: .accentColor)
            SingleScoreView(courseScore: .example, color: .accentColor)
                .noGPAView
            SingleScoreView(courseScore: .example, color: .accentColor)
                .noScoreView
        }
        .padding(.horizontal)
    }
}
