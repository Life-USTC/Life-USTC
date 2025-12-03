import SwiftUI

enum CurriculumPreview {
    @ViewBuilder
    static var titleView: some View {
        Text("Class")
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.mint)
            )
    }

    @ViewBuilder
    static func makeListWidget(
        with lectures_: [Lecture],
        color: Color = Color.accentColor,
        numberToShow: Int = 2
    ) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                titleView
                Spacer()

                Text(String(format: "Total: %@ lectures".localized, String(lectures_.count)))
                    .font(.system(.caption, design: .monospaced, weight: .light))
            }
            .padding(.bottom, 10)

            // let lectures = lectures_.isEmpty ? Array(repeating: .example, count: 6) : lectures_
            let lectures = lectures_

            ZStack {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(lectures.prefix(numberToShow).enumerated()), id: \.1.id) { index, lecture in
                        LectureView(lecture: lecture)
                    }
                }
                .if(lectures_.isEmpty) {
                    $0
                        .redacted(reason: .placeholder)
                        .blur(radius: 5)
                }

                if lectures_.isEmpty {
                    Text("No courses today!")
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

extension CurriculumPreview {
    @ViewBuilder
    static func makeDayWidget(
        with lecture_: Lecture?
    ) -> some View {
        // let lecture = lecture_ ?? .example
        let lecture = lecture_!

        ZStack {
            VStack(alignment: .leading) {
                HStack {
                    titleView

                    Text(lecture.location)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundColor(.mint)
                }
                .padding(.bottom, 3)

                Text(lecture.name)
                    .lineLimit(2)
                    .fontWeight(.bold)

                Spacer()

                Text(lecture.startDate.stripHMwithTimezone())
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.mint)
                HStack {
                    Text(lecture.endDate.stripHMwithTimezone())
                    Spacer()
                    Text(lecture.teacherName)
                        .lineLimit(1)
                }
                .font(.subheadline)
                .fontWeight(.regular)
                .foregroundColor(.gray.opacity(0.8))
            }
            .if(lecture_ == nil) {
                $0
                    .redacted(reason: .placeholder)
                    .blur(radius: 5)
            }

            if lecture_ == nil {
                VStack(alignment: .center, spacing: 20) {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 50))
                        .fontWeight(.regular)
                        .frame(width: 60, height: 60)
                        .padding(5)
                        .fontWeight(.heavy)
                        .foregroundColor(.mint.opacity(0.8))
                    Text("No courses today!")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .dynamicTypeSize(.medium)
    }
}
