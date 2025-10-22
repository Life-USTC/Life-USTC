//
//  BuildingImgMapping.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import Foundation
import SwiftyJSON

/// Mapping from building names to image paths using regex patterns
struct BuildingImgMappingData: Codable, ExampleDataProtocol {
    struct Mapping: Codable {
        var regex: String
        var path: String
    }
    var data: [Mapping]

    static let example = BuildingImgMappingData(data: [
        Mapping(regex: ".*", path: "https://example.com/default.png")
    ])

    /// Get image URL for a building name
    /// - Parameters:
    ///   - baseURL: Base URL for images (defaults to school's building image base URL)
    ///   - buildingName: Name of the building to find image for
    /// - Returns: Full URL to building image, or nil if no match found
    func getURL(baseURL: URL = SchoolExport.shared.buildingimgBaseURL, buildingName: String) -> URL? {
        if let mapping =
            (data.first {
                buildingName.range(of: $0.regex, options: .regularExpression) != nil
            })
        {
            return baseURL.appendingPathComponent(mapping.path)
        }
        return nil
    }
}

/// Delegate for fetching building image mapping data
class BuildingImgMappingDelegate: ManagedRemoteUpdateProtocol<BuildingImgMappingData> {
    static let shared = BuildingImgMappingDelegate()

    override func refresh() async throws -> BuildingImgMappingData {
        let url = SchoolExport.shared.buildingimgMappingURL

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSON(data: data)
        return BuildingImgMappingData(
            data: json.arrayValue
                .map {
                    let regex = $0["regex"].stringValue
                    let path = $0["path"].stringValue
                    return BuildingImgMappingData.Mapping(regex: regex, path: path)
                }
        )
    }
}

extension ManagedDataSource<BuildingImgMappingData> {
    static let buildingImgMapping = ManagedDataSource(
        local: ManagedLocalStorage("buildingImgMapping"),
        remote: BuildingImgMappingDelegate.shared
    )
}
