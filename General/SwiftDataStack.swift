import SwiftData
import SwiftUI

enum SwiftDataStack {
    static let modelContainer: ModelContainer = {
        let schema = Schema([
            Course.self,
            Curriculum.self,
            Exam.self,
            Homework.self,
            Lecture.self,
            Score.self,
            Semester.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier("group.dev.tiankaima.Life-USTC")
        )

        return try! ModelContainer(for: schema, configurations: [modelConfiguration])
    }()

    @MainActor static let modelContext = modelContainer.mainContext
}
