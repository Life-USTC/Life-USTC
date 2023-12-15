//
//  ExamPreview.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import Combine
import SwiftUI

struct ExamView: View {
    var exam: Exam
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(exam.isFinished ? .gray : .cyan)
                .frame(width: 5)
                .frame(maxHeight: 50)
            VStack(alignment: .leading) {
                Text(exam.courseName)
                    .fontWeight(.bold)
                    .strikethrough(exam.isFinished)
                Text(exam.classRoomName)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .bold()
                HStack {
                    Text(exam.startDate, format: .dateTime.day().month())
                    Text(exam.startDate ... exam.endDate)
                }
                .lineLimit(1)
                .font(
                    .system(.caption, design: .monospaced, weight: .medium)
                )
            }
            Spacer()
        }
    }
}

struct ExamWidgetView: View {
    var exam: Exam
    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading) {
                Text(exam.courseName)
                    .font(.headline)
                    .strikethrough(exam.isFinished)
                    .bold()
                HStack {
                    Text(exam.startDate, format: .dateTime.day().month())
                        .fontWeight(.heavy)
                        .foregroundColor(.blue.opacity(0.8))
                    Text(exam.startDate ... exam.endDate)
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.8))
                    Text(exam.classRoomName)
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.8))
                }
            }
            Spacer()
            if exam.isFinished {
                Text("Finished".localized)
                    .foregroundColor(.gray)
                    .font(.subheadline)
                    .fontWeight(.heavy)
            } else {
                Text(
                    exam.daysLeft == 1
                        ? "1 day left".localized : String(format: "%@ days left".localized, String(exam.daysLeft))
                )
                .foregroundColor(exam.daysLeft <= 7 ? .red.opacity(0.8) : .blue.opacity(0.8))
                .font(.subheadline)
                .fontWeight(.heavy)
            }
        }
    }
}

struct ExamPreview: View {
    var exams: [Exam] = []
    var numberToShow: Int = 1
    @ViewBuilder
    func makeWidget(
        with exam: Exam?,
        color: Color = .cyan
    )
        -> some View
    {
        if let exam {
            VStack(alignment: .leading) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Exam")
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(color.opacity(0.8))
                            )
                        Text(exam.startDate, format: .dateTime.day().month())
                            .font(.callout)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .foregroundColor(color)
                    }
                    Text(exam.courseName)
                        .lineLimit(2)
                        .fontWeight(.bold)
                }
                Spacer()
                VStack(alignment: .leading) {
                    HStack(alignment: .lastTextBaseline) {
                        Text(
                            exam.daysLeft == 1
                                ? "1 day left".localized
                                : String(format: "%@ days left".localized, String(exam.daysLeft))
                        )
                        .foregroundColor(exam.daysLeft <= 7 ? .red.opacity(0.8) : color.opacity(0.8))
                        .font(.title3)
                        .fontWeight(.semibold)
                    }
                    HStack {
                        Text(exam.startDate, format: .dateTime.hour().minute())
                        Spacer()
                        Text(exam.classRoomName)
                    }
                    .lineLimit(1)
                    .foregroundColor(.gray.opacity(0.8))
                    .font(.subheadline)
                    .fontWeight(.regular)
                }
            }
        } else {
            VStack(alignment: .center, spacing: 20) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 50))
                    .fontWeight(.regular)
                    .frame(width: 60, height: 60)
                    .padding(5)
                    .fontWeight(.heavy)
                    .foregroundColor(color)
                Text("No More Exam!")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }

    @ViewBuilder
    func makeListWidget(
        with exams: [Exam],
        color: Color = .cyan,
        numberToShow: Int = 2
    )
        -> some View
    {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Exam")
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                    )
                Spacer()
            }
            .padding(.bottom, 10)

            if exams.isEmpty {
                Text("No More Exam!")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(exams.clean().prefix(numberToShow).enumerated()), id: \.1.id) { index, exam in
                    ExamWidgetView(exam: exam)
                    
                    if index < exams.count - 1 && index < numberToShow - 1 {
                        Divider()
                            .padding(.vertical, 7)
                    }
                }
                Spacer()
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(exams.clean()) { exam in
                ExamView(exam: exam)
            }
            if exams.isEmpty {
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color("AccentColor"))
                        .frame(width: 5)
                        .frame(minHeight: 40, maxHeight: 50)
                    VStack(alignment: .leading) {
                        Text("No More Exam!")
                            .fontWeight(.bold)
                        Text("Enjoy!")
                            .font(.system(.caption, design: .monospaced))
                    }
                    Spacer()
                }
            }
        }
    }
}
