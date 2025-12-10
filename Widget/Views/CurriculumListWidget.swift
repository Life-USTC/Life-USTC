import SwiftUI

struct CurriculumListWidget: View {
    let lectures: [Lecture]
    var color: Color = .accentColor
    var numberToShow: Int = 2

    var body: some View {
        Group {
            if lectures.isEmpty {
                ContentUnavailableView(
                    "No courses today!",
                    systemImage: "moon.stars"
                )
            } else {
                VStack(spacing: 0) {
                    HStack(alignment: .bottom) {
                        CurriculumTitleView()
                        Spacer()

                        Text(String(format: "Total: %@ lectures".localized, String(lectures.count)))
                            .font(.system(.caption, design: .monospaced, weight: .light))
                    }
                    .padding(.bottom, 10)

                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(lectures.prefix(numberToShow), id: \.id) { lecture in
                            LectureView(lecture: lecture)
                        }
                    }

                    Spacer()
                }
            }
        }
        .dynamicTypeSize(.medium)
    }
}
