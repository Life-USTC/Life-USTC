import SwiftUI

struct LectureView: View {
    var lecture: Lecture

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(lecture.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                HStack {
                    Text("\(lecture.teacherName)")
                        .lineLimit(1)
                    Text("@ **\(lecture.location)**")
                        .lineLimit(1)
                }
                .font(.footnote)
                .foregroundColor(.gray.opacity(0.8))
            }

            Spacer()

            VStack(alignment: .trailing) {
                // Times:
                Text(lecture.startDate.stripHMwithTimezone())
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.mint)
                Text(lecture.endDate.stripHMwithTimezone())
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.8))
            }
            .if(lecture.isFinished) {
                $0.strikethrough()
            }
        }
        .padding(.leading, 15)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .background {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(lecture.color)
                    .frame(width: 5)
                RoundedCornersShape(corners: [.topRight, .bottomRight], radius: 5)
                    .fill(lecture.color.opacity(0.05))
            }
        }
        .if(lecture.isFinished) {
            $0.grayscale(1.0)
        }
    }
}
