import SwiftData
import SwiftUI

enum SwiftDataStack {
    static let modelContainer: ModelContainer = {
        let schema = Schema([
            Curriculum.self,
            Semester.self,
            Course.self,
            Lecture.self,

            Exam.self,
            Homework.self,

            Score.self,
            ScoreEntry.self,

            FeedSource.self,
            Feed.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier("group.dev.tiankaima.Life-USTC")
        )

        return try! ModelContainer(for: schema, configurations: [modelConfiguration])
    }()

    @MainActor static var modelContext: ModelContext { modelContainer.mainContext }
}
