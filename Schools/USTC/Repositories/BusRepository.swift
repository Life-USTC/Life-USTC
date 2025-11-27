import Foundation
import SwiftData

enum BusRepository {
    static func refresh() async throws {
        let url = URL(string: "\(staticURLPrefix)/bus_data_v3.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let context = SwiftDataStack.context
        try context.cacheJSON(key: "bus_data", data: data)
    }

    static func get() throws -> USTCBusData? {
        let context = SwiftDataStack.context
        guard let data = try context.getCachedJSON(key: "bus_data") else { return nil }
        return try JSONDecoder().decode(USTCBusData.self, from: data)
    }
}
