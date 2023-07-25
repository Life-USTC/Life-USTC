//
//  USTC+QCKD.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/24.
//

import SwiftUI
import SwiftyJSON

class UstcQCKDEvent: Identifiable, Equatable, Codable, ObservableObject {
    private var json: JSON
    var children: [UstcQCKDEvent] = []

    static func == (lhs: UstcQCKDEvent, rhs: UstcQCKDEvent) -> Bool {
        lhs.id == rhs.id
    }

    var id: String {
        json["self"]["id"].stringValue
    }

    var name: String {
        json["self"]["itemName"].stringValue
    }

    var imageURL: URL {
        URL(string: "https://young.ustc.edu.cn/login/\(json["self"]["pic"].stringValue)")!
    }

    var ratingTxt: String {
        "\(json["rating"]["avgNum"].stringValue) [\(json["rating"]["evaluationNum"].stringValue)/\(json["rating"]["registrationNum"].stringValue)]"
    }

    var timeDescription: String {
        "\(json["self"]["st"].stringValue) - \(json["self"]["et"].stringValue)"
    }

    var startTime: String {
        json["self"]["st"].stringValue
    }

    var endTime: String {
        json["self"]["et"].stringValue
    }

    var infoDescription: String {
        "\(json["self"]["moduleName"].stringValue) [\(json["self"]["formName"].stringValue)]"
    }

    var description: String {
        json["self"]["baseContent"].stringValue
    }

    var hostingDepartment: String {
        json["self"]["sponsorNames"].stringValue
    }

    var contactInformation: String {
        json["self"]["linkMan"].stringValue + " " + json["self"]["tel"].stringValue
    }

    init(json: JSON, children: [UstcQCKDEvent] = []) {
        self.json = json
        self.children = children
        // json["self"], json["children"], json["rating"]
    }

    enum CodingKeys: CodingKey {
        case json
        case children
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        json = try container.decode(JSON.self, forKey: .json)
        children = try container.decode([UstcQCKDEvent].self, forKey: .children)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(json, forKey: .json)
        try container.encode(children, forKey: .children)
    }
}

struct UstcQCKDModel: Codable {
    var eventLists: [String: [UstcQCKDEvent]] = [:]
}
