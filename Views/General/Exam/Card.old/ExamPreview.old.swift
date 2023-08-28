//
//  ExamPreview.old.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/28.
//

import SwiftUI

struct ExamPreview_old: View {
    var exams: [Exam]

    var body: some View {
        Group {
            if exams.isEmpty {
                happyView
            } else {
                makeView(with: exams)
            }
        }
    }

    func makeView(with exams: [Exam]) -> some View {
        VStack {
            ForEach(exams) { exam in
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading) {
                            Text(exam.courseName)
                                .fontWeight(.bold)
                                .strikethrough(exam.isFinished)
                            Text(exam.classRoomName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(exam.startDate, style: .date)
                            Text(exam.endDate, style: .date)
                                .font(.caption)
                                .foregroundColor(Color.secondary)
                        }
                        .font(.system(.body, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    Spacer()
                    if exam.isFinished {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray)
                            .frame(height: 5)
                    } else {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [.red, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 5)
                    }
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

    var happyView: some View {
        VStack {
            Spacer()
            HStack {
                ZStack {
                    Image(systemName: "checklist.checked")
                        .symbolRenderingMode(.hierarchical)
                        .fontWeight(.light)
                        .font(.largeTitle)
                        .foregroundStyle(Color.orange)
                }

                Spacer()

                Text("No More Exam!")
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

#Preview{
    ExamPreview_old(exams: [.example])
}
