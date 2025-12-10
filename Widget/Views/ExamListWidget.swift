import SwiftUI

struct ExamListWidget: View {
    let exams: [Exam]
    var numberToShow: Int = 2

    var body: some View {
        Group {
            if exams.isEmpty {
                ContentUnavailableView(
                    "No More Exam!",
                    systemImage: "calendar.badge.checkmark"
                )

            } else {
                VStack(spacing: 0) {
                    HStack(alignment: .bottom) {
                        ExamTitleView()
                        Spacer()

                        Text(String(format: "Total: %@ exams".localized, String(exams.count)))
                            .font(.system(.caption, design: .monospaced, weight: .light))
                    }
                    .padding(.bottom, 10)

                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(exams.prefix(numberToShow), id: \.id) { exam in
                            ExamView(exam: exam)
                        }
                    }

                    Spacer()
                }
            }
        }
        .dynamicTypeSize(.medium)
    }
}
