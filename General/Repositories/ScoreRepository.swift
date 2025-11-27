import Foundation
import SwiftData

enum ScoreRepository {
    static func refresh() async throws {
        let score = try await SchoolSystem.current.scoreFetch()
        let context = SwiftDataStack.context
        try context.replaceSingle(Score.self, with: score)
    }
}
