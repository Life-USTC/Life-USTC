import Foundation
import SwiftData
import SwiftyJSON

enum BuildingImgMappingRepository {
    static func refresh() async throws {
        let (data, _) = try await URLSession.shared.data(from: SchoolSystem.current.buildingimgMappingURL)
        let json = try JSON(data: data)
        let mappings: [BuildingImgRule] = json.arrayValue.map { item in
            BuildingImgRule(
                regex: item["regex"].stringValue,
                path: item["path"].stringValue
            )
        }

        let context = SwiftDataStack.context
        try context.replaceAll(BuildingImgRule.self, with: mappings)
    }
}
