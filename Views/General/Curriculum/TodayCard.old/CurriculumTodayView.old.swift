//
//  CurriculumTodayView.old.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/28.
//

import SwiftUI

struct CurriculumTodayView_old: View {
    var lectures: [Lecture]

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(lectures) { lecture in
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading) {
                            Text(lecture.name.truncated(length: 10))
                                .fontWeight(.bold)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Text(lecture.location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(lecture.startDate ... lecture.endDate)
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 5)
                }
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(style: .init(lineWidth: 1))
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(height: 60)
            }

            if lectures.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "calendar")
                            .symbolRenderingMode(.hierarchical)
                            .fontWeight(.light)
                            .font(.largeTitle)
                            .foregroundColor(.orange)

                        Spacer()

                        Text("Nothing here")
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.orange)
                        .frame(height: 5)
                }
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(style: .init(lineWidth: 1))
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(height: 60)
            }
        }
    }
}

#Preview{
    CurriculumTodayView_old(lectures: [.example])
}
