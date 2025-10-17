//
//  ExamPreview.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import Combine
import SwiftUI

struct ExamItemView: View {
    var exam: Exam
    var color: Color = .blue

    var examColor: Color {
        exam.daysLeft <= 7 ? .red.opacity(0.8) : color.opacity(0.8)
    }

    var isFinished: Bool {
        exam.isFinished
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(exam.courseName)
                    .font(.headline)
                    .fontWeight(.bold)
                Text("\(exam.startDate, format: .dateTime.day().month()) @ **\(exam.classRoomName)**")
                    .font(.footnote)
                    .foregroundColor(.gray.opacity(0.8))
            }

            Spacer()

            VStack(alignment: .trailing) {
                if isFinished {
                    Text("Finished")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                        .fontWeight(.heavy)
                } else {
                    Text(RelativeDateTimeFormatter().localizedString(for: exam.startDate, relativeTo: Date()))
                        .foregroundColor(examColor)
                        .font(.subheadline)
                        .fontWeight(.heavy)
                }
                Text(exam.startDate ... exam.endDate)
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
                    .fill(examColor)
                    .frame(width: 5)
                RoundedCornersShape(corners: [.topRight, .bottomRight], radius: 5)
                    .fill(examColor.opacity(0.05))
            }
        }
        .if(isFinished) {
            $0
                .strikethrough()
                .grayscale(1.0)
        }
    }
}

struct ExamPreview: View {
    var exams: [Exam] = []
    var color: Color = .blue

    @ViewBuilder
    var noExamView: some View {
        ZStack {
            ExamItemView(exam: .example)
                .redacted(reason: .placeholder)

            VStack {
                Text("No More Exam!")
                    .lineLimit(1)
                    .font(.system(.body, weight: .semibold))

                Text("Enjoy!")
                    .lineLimit(1)
                    .font(.caption)
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(exams) { exam in
                ExamItemView(exam: exam, color: color)
            }

            if exams.isEmpty {
                noExamView
            }
        }
    }
}

extension ExamPreview {
    @ViewBuilder
    static var titleView: some View {
        Text("Exam")
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.blue.opacity(0.8))
            )
    }

    @ViewBuilder
    static func makeListWidget(
        with exams_: [Exam],
        color: Color = Color.blue,
        numberToShow: Int = 2
    ) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                titleView
                Spacer()

                Text(String(format: "Total: %@ exams".localized, String(exams_.count)))
                    .font(.system(.caption, design: .monospaced, weight: .light))
            }
            .padding(.bottom, 10)

            let exams = exams_.isEmpty ? Array(repeating: .example, count: 4) : exams_

            ZStack {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(exams.prefix(numberToShow).enumerated()), id: \.1.id) { index, exam in
                        ExamItemView(exam: exam, color: color)
                    }
                }
                .if(exams_.isEmpty) {
                    $0
                        .redacted(reason: .placeholder)
                        .blur(radius: 5)
                }

                if exams_.isEmpty {
                    Text("No More Exam!")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            if numberToShow >= 2 {
                Spacer()
            }
        }
        .dynamicTypeSize(.medium)
    }
}

extension ExamPreview {
    @ViewBuilder
    static func makeDayWidget(
        with exam_: Exam?
    ) -> some View {
        let exam = exam_ ?? .example

        ZStack {
            VStack(alignment: .leading) {
                HStack {
                    titleView

                    Text(exam.classRoomName)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundColor(.blue)
                }
                .padding(.bottom, 3)

                Text(exam.courseName)
                    .lineLimit(2)
                    .fontWeight(.bold)

                Spacer()

                let daysLeftText =
                    exam.daysLeft == 1
                    ? "1 day left".localized : String(format: "%@ days left".localized, String(exam.daysLeft))
                Text(daysLeftText)
                    .foregroundColor(exam.daysLeft <= 7 ? .red.opacity(0.8) : .blue.opacity(0.8))
                    .font(.title3)
                    .fontWeight(.semibold)

                HStack {
                    Text(exam.startDate, format: .dateTime.hour().minute())
                    Spacer()
                    Text(exam.startDate, format: .dateTime.day().month())
                }
                .font(.subheadline)
                .fontWeight(.regular)
                .foregroundColor(.gray.opacity(0.8))
            }
            .if(exam_ == nil) {
                $0
                    .redacted(reason: .placeholder)
                    .blur(radius: 5)
            }

            if exam_ == nil {
                VStack(alignment: .center, spacing: 20) {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 50))
                        .fontWeight(.regular)
                        .frame(width: 60, height: 60)
                        .padding(5)
                        .fontWeight(.heavy)
                        .foregroundColor(.blue.opacity(0.8))
                    Text("No More Exam!")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .dynamicTypeSize(.medium)
    }
}

#Preview {
    TabView {
        ForEach(0 ..< 10) { count in
            NavigationStack {
                ExamPreview
                    .makeListWidget(
                        with: Array(repeating: .example, count: count),
                        color: .blue,
                        numberToShow: 4
                    )
                    .card()
                    .border(.blue)
                    .frame(height: 400)
            }
        }
    }
}

#Preview {
    NavigationStack {
        VStack {
            ExamPreview
                .makeDayWidget(with: nil)
                .frame(width: 200, height: 200)

            ExamPreview
                .makeDayWidget(with: .example)
                .frame(width: 200, height: 200)
        }
    }
}
