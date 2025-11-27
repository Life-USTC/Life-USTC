import Foundation
import SwiftData

enum FeedRepository {
    static func refresh() async throws {
        let sources = try await FeedDelegate.shared.refresh()
        let context = SwiftDataStack.context
        try context.replaceAll(FeedSource.self, with: sources)
    }
}
