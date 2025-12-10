//
//  ScoreEntryView.swift
//  Life@USTC
//
//  Created by TiankaiMa on 2023/1/12.
//

import SwiftUI

struct ScoreEntryView: View {
    var entry: ScoreEntry
    var color: Color

    var cornerRadius: CGFloat = {
        guard #available(iOS 26, *) else {
            return 5
        }
        return 10
    }()

    @ViewBuilder
    var emptyScoreView: some View {
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
    }

    @ViewBuilder
    var passFailScoreView: some View {
        Text(entry.score)
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

    @ViewBuilder
    var numericScoreView: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(entry.score)
                .frame(width: 35)
                .padding(.horizontal, 4)
            Divider()
            Text(String(format: "%.1f", entry.gpa ?? 0))
                .frame(width: 35)
                .padding(.horizontal, 4)
        }
        .frame(width: 85, height: 30)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(color)
        )
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(entry.courseName)
                    .fontWeight(.bold)
                HStack {
                    Text(String(entry.credit))
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    Text(entry.courseCode)
                        .foregroundColor(.gray)
                }
                .font(.subheadline)
            }

            Spacer()

            Group {
                if entry.gpa == nil {
                    if entry.score.isEmpty {
                        emptyScoreView
                    } else {
                        passFailScoreView
                    }
                } else {
                    numericScoreView
                }
            }
            .font(.body)
            .fontWeight(.bold)
            .foregroundColor(.white)
        }
    }
}
