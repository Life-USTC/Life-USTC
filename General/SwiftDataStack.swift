import SwiftData
import SwiftUI

enum SwiftDataStack {
    private static let schema = Schema([
        Curriculum.self,
        Semester.self,
        Course.self,
        Lecture.self,

        Exam.self,
        Homework.self,

        ScoreSheet.self,
        ScoreEntry.self,

        FeedSource.self,
        Feed.self,
    ])

    private static let productionContainer: ModelContainer = {
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier("group.dev.tiankaima.Life-USTC")
        )

        return try! ModelContainer(for: schema, configurations: [modelConfiguration])
    }()

    private static let demoContainer: ModelContainer = {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        DemoData.seed(context)
        return container
    }()

    private static var shouldUseDemoData: Bool {
        UserDefaults.appGroup.bool(forKey: "appShouldPresentDemo")
    }

    static var isPresentingDemo: Bool { shouldUseDemoData }

    #if DEBUG
    private static let testContainer: ModelContainer = {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()
    #endif

    static func container(forDemo: Bool) -> ModelContainer {
        if forDemo { return demoContainer }
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["UI_TEST_SERVER_URL"],
            let url = URL(string: raw), url.scheme == "http",
            ["127.0.0.1", "localhost", "::1"].contains(url.host ?? "") {
            return testContainer
        }
        #endif
        return productionContainer
    }

    static var modelContainer: ModelContainer {
        container(forDemo: shouldUseDemoData)
    }

    @MainActor static var modelContext: ModelContext { modelContainer.mainContext }
}
