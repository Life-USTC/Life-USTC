import Foundation
import SwiftData

enum HomeworkRepository {
    static func refresh() async throws {
        let homeworks = try await SchoolSystem.current.homeworkFetch()
        let context = SwiftDataStack.context
        try context.replaceAll(Homework.self, with: homeworks)
    }
}
