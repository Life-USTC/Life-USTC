import SwiftUI

struct ExamView: View {
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
