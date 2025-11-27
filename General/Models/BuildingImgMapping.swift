//
//  BuildingImgMapping.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import Foundation
import SwiftData

@Model
final class BuildingImgRule {
    var regex: String
    var path: String

    init(regex: String, path: String) {
        self.regex = regex
        self.path = path
    }
}
