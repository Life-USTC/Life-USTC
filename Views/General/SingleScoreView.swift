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

    var cornerRadius: CGFloat = {
        guard #available(iOS 26, *) else {
            return 5
        }
        return 10
    }()

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

            Group {
                if courseScore.gpa == nil {
                    if courseScore.score.isEmpty {
                        Image(systemName: "xmark")
                            .frame(width: 85, height: 30)
                            .background(
                                Stripes(
                                    config: .init(
                                        background: .gray,
                                        foreground: .white.opacity(0.4)
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                            )
                    } else {
                        Text("\(String(courseScore.score))")
                            .frame(width: 85, height: 30)
                            .background(
                                Stripes(
                                    config: .init(
                                        background: .cyan,
                                        foreground: .white.opacity(0.4)
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                            )
                    }
                } else {
                    HStack(alignment: .center, spacing: 0) {
                        Text("\(courseScore.score)")
                            .frame(width: 35)
                            .padding(.horizontal, 4)
                        Divider()
                        Text("\(String(courseScore.gpa!))")
                            .frame(width: 35)
                            .padding(.horizontal, 4)
                    }
                    .frame(width: 85, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(color)
                    )
                }
            }
            .font(.body)
            .fontWeight(.bold)
            .foregroundColor(.white)
        }
    }
}

struct SingleScoreView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .trailing) {
            SingleScoreView(courseScore: .example, color: .accentColor)
        }
        .padding(.horizontal)
    }
}
