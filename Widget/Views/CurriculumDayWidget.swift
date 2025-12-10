import SwiftUI

struct CurriculumDayWidget: View {
    let lecture: Lecture!

    var mainView: some View {
        VStack(alignment: .leading) {
            HStack {
                CurriculumTitleView()

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
        .if(lecture.isFinished) {
            $0.grayscale(1.0)
        }
    }

    var body: some View {
        Group {
            if lecture != nil {
                mainView
            } else {
                ContentUnavailableView(
                    "No courses today!",
                    systemImage: "moon.stars"
                )
            }
        }
        .dynamicTypeSize(.medium)
    }
}
