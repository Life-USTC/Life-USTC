import Foundation
import SwiftData

enum CurriculumRepository {
    static func refresh() async throws {
        let curriculum = try await SchoolSystem.current.curriculumFetch()
        let context = SwiftDataStack.context
        try context.replaceAll(Semester.self, with: curriculum.semesters)
    }
}
