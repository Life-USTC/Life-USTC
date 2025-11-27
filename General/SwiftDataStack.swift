import Foundation
import SwiftData

enum SwiftDataStack {
    static let container: ModelContainer = {
        let schema = Schema([
            Exam.self,
            Homework.self,
            Semester.self,
            Course.self,
            Lecture.self,
            Score.self,
            CourseScore.self,
            FeedSource.self,
            Feed.self,
        ])

        let config = ModelConfiguration(
            groupContainer: .identifier("group.life.ustc.Life-USTC")
        )

        return try! ModelContainer(
            for: schema,
            configurations: config
        )
    }()

    static var context: ModelContext = {
        ModelContext(container)
    }()
}
