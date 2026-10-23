import Foundation

enum ServerDescriptionTarget: Equatable {
    case course(jwId: Int)
    case section(jwId: Int)
    case teacher(id: Int)
    case homework(id: String)

    var targetType: String {
        switch self {
        case .course: "course"
        case .section: "section"
        case .teacher: "teacher"
        case .homework: "homework"
        }
    }

    var queryItems: [URLQueryItem] {
        let identifier: URLQueryItem
        switch self {
        case .course(let id): identifier = .init(name: "courseJwId", value: String(id))
        case .section(let id): identifier = .init(name: "sectionJwId", value: String(id))
        case .teacher(let id): identifier = .init(name: "teacherId", value: String(id))
        case .homework(let id): identifier = .init(name: "homeworkId", value: id)
        }
        return [.init(name: "targetType", value: targetType), identifier]
    }
}

struct ServerDescriptionUpsertRequest: Encodable {
    let target: ServerDescriptionTarget
    let content: String

    private enum CodingKeys: String, CodingKey {
        case targetType, courseJwId, sectionJwId, teacherId, homeworkId, content
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(target.targetType, forKey: .targetType)
        try container.encode(content, forKey: .content)
        switch target {
        case .course(let id): try container.encode(id, forKey: .courseJwId)
        case .section(let id): try container.encode(id, forKey: .sectionJwId)
        case .teacher(let id): try container.encode(id, forKey: .teacherId)
        case .homework(let id): try container.encode(id, forKey: .homeworkId)
        }
    }
}

struct ServerDescriptionContent: Codable {
    let id: String?
    let content: String
    let renderedHtml: String
    let updatedAt: Date?
    let lastEditedAt: Date?
    let lastEditedBy: ServerHomeworkCreator?
}

struct ServerDescriptionEdit: Codable, Identifiable {
    let id: String
    let createdAt: Date
    let previousContent: String?
    let nextContent: String
    let editor: ServerHomeworkCreator?
}

struct ServerDescriptionResponse: Codable {
    let description: ServerDescriptionContent
    let history: [ServerDescriptionEdit]
    let viewer: ServerCommentViewer
}

struct ServerDescriptionUpsertResponse: Codable {
    let id: String
    let updated: Bool
}

struct ServerCommentThreadTarget: Codable {
    let sectionId: Int?
    let courseId: Int?
    let teacherId: Int?
    let sectionTeacherId: Int?
    let sectionTeacherSectionId: Int?
    let sectionTeacherTeacherId: Int?
    let sectionTeacherSectionJwId: Int?
    let sectionTeacherSectionCode: String?
    let sectionTeacherTeacherName: String?
    let sectionTeacherCourseJwId: Int?
    let sectionTeacherCourseName: String?
    let homeworkId: String?
    let youngEventId: Int?
    let youngId: String?
    let homeworkTitle: String?
    let homeworkSectionJwId: Int?
    let homeworkSectionCode: String?
    let sectionJwId: Int?
    let sectionCode: String?
    let courseJwId: Int?
    let courseName: String?
    let teacherName: String?
    let youngEventName: String?

    var commentSelector: (type: String, id: String)? {
        if let sectionTeacherId { return ("section-teacher", String(sectionTeacherId)) }
        if let homeworkId { return ("homework", homeworkId) }
        if let youngEventId { return ("young-event", String(youngEventId)) }
        if let sectionId { return ("section", String(sectionId)) }
        if let courseId { return ("course", String(courseId)) }
        if let teacherId { return ("teacher", String(teacherId)) }
        return nil
    }
}

struct ServerCommentThreadResponse: Codable {
    let thread: [ServerComment]
    let focusId: String
    let hiddenCount: Int
    let viewer: ServerCommentViewer
    let target: ServerCommentThreadTarget
}

struct ServerPublicUserProfile: Codable {
    struct User: Codable, Identifiable {
        struct Counts: Codable {
            let comments: Int
            let uploads: Int
            let homeworksCreated: Int
        }

        let id: String
        let username: String?
        let name: String?
        let image: String?
        let createdAt: Date
        let counts: Counts

        private enum CodingKeys: String, CodingKey {
            case id, username, name, image, createdAt
            case counts = "_count"
        }
    }

    struct ContributionDay: Codable, Identifiable {
        let date: String
        let count: Int

        var id: String { date }
    }

    let user: User
    let weeks: [[ContributionDay]]
    let totalContributions: Int
}

enum ServerHomeworkAuditAction: String, Codable {
    case created, updated, deleted
}

struct ServerHomeworkAuditLog: Codable, Identifiable {
    let id: String
    let action: ServerHomeworkAuditAction
    let titleSnapshot: String?
    let createdAt: Date
    let sectionId: Int
    let homeworkId: String?
    let actorId: String?
    let actor: ServerHomeworkCreator?
}

struct ServerHomeworkAuditResponse: Codable {
    let auditLogs: [ServerHomeworkAuditLog]
}

struct ServerHomeworkCreateResponse: Codable {
    let id: String
    let homework: ServerHomework
}

struct ServerHomeworkUpdateResponse: Codable {
    let success: Bool
    let homework: ServerHomework
}
