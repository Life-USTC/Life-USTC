import Foundation
import SwiftData

enum ExamRepository {
    static func refresh() async throws {
        let exams = try await SchoolSystem.current.examFetch()
        let context = SwiftDataStack.context
        try context.replaceAll(Exam.self, with: exams)
    }
}
