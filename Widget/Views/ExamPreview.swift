import SwiftUI

enum ExamPreview {
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

            let exams = exams_

            if exams_.isEmpty {
                ContentUnavailableView(
                    "No More Exam!",
                    systemImage: "calendar.badge.checkmark"
                )
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(exams.prefix(numberToShow).enumerated()), id: \.1.id) { index, exam in
                        ExamView(exam: exam, color: color)
                    }
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
        let exam = exam_!

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

            if exam_ == nil {
                ContentUnavailableView(
                    "No More Exam!",
                    systemImage: "moon.stars",
                    description: Text("Enjoy!")
                )
            }
        }
        .dynamicTypeSize(.medium)
    }
}
