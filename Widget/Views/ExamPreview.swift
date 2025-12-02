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

            // let exams = exams_.isEmpty ? Array(repeating: .example, count: 4) : exams_
            let exams = exams_

            ZStack {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(exams.prefix(numberToShow).enumerated()), id: \.1.id) { index, exam in
                        ExamView(exam: exam, color: color)
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
