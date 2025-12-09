import Foundation
import SwiftyJSON

struct BuildingImgRule {
    var regex: String
    var path: String

    init(regex: String, path: String) {
        self.regex = regex
        self.path = path
    }
}

typealias BuildingImgMapping = [BuildingImgRule]

extension BuildingImgMapping {
    static func fetch() async throws -> Self {
        let (data, _) = try await URLSession.shared.data(from: SchoolSystem.current.buildingimgMappingURL)
        let json = try JSON(data: data)

        return json.arrayValue.map { item in
            BuildingImgRule(
                regex: item["regex"].stringValue,
                path: item["path"].stringValue
            )
        }
    }

    static func getImageURL(for location: String) async throws -> URL? {
        let mapping = try await fetch()
        for rule in mapping {
            if location.range(of: rule.regex, options: .regularExpression) != nil {
                return URL(string: SchoolSystem.current.buildingimgBaseURL.absoluteString + rule.path)
            }
        }
        return nil
    }
}
