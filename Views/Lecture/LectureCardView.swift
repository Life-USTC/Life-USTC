import SwiftUI

struct LectureCardView: View {
    var lecture: Lecture

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 5)
                .fill(lecture.color.opacity(0.2))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(lecture.startDate.clockTime)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))

                Group {
                    Text(lecture.name)
                        .lineLimit(2, reservesSpace: false)
                        .font(.system(size: 10, weight: .light))
                    Text(lecture.location)
                        .lineLimit(2, reservesSpace: false)
                        .font(.system(size: 12, weight: .light, design: .monospaced))
                }

                Spacer()

                if lecture.length >= 2 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(lecture.teacherName)
                            .lineLimit(1, reservesSpace: false)
                            .font(.system(size: 8))

                        Text(lecture.endDate.clockTime)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                    }
                    .hStackTrailing()
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
        }
        .lectureSheet(lecture: lecture)
    }
}
