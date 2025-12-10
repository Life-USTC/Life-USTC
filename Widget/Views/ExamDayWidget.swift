import SwiftUI

struct ExamDayWidget: View {
    let exam: Exam!

    var mainView: some View {
        VStack(alignment: .leading) {
            HStack {
                ExamTitleView()

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

            Text(exam.startDate, style: .relative)
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
        .if(exam.isFinished) {
            $0.grayscale(1.0)
        }
    }

    var body: some View {
        Group {
            if exam != nil {
                mainView
            } else {
                ContentUnavailableView(
                    "No More Exam!",
                    systemImage: "calendar.badge.checkmark"
                )
            }
        }
        .dynamicTypeSize(.medium)
    }
}
