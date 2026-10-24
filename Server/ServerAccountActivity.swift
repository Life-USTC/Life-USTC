import Foundation

struct ServerAccountActivityPage: Decodable {
    let items: [ServerAccountActivity]
    let nextCursor: String?
}

struct ServerAccountActivity: Decodable, Identifiable {
    enum Outcome: String, Decodable {
        case success, denied, failure
    }

    let id: String
    let action: String
    let outcome: Outcome
    let channel: String
    let createdAt: Date
    let targetType: String?

    var title: String {
        switch action {
        case "comment_create": "Comment posted".localized
        case "comment_edit": "Comment edited".localized
        case "comment_delete": "Comment deleted".localized
        case "comment_react": "Comment reaction changed".localized
        case "description_edit": "Description edited".localized
        case "upload_delete": "File deleted".localized
        case "homework_create": "Homework created".localized
        case "homework_update": "Homework updated".localized
        case "homework_delete": "Homework deleted".localized
        case "oauth_authorization_grant": "App authorized".localized
        case "oauth_authorization_update": "App authorization updated".localized
        case "oauth_authorization_revoke": "App authorization revoked".localized
        default: action.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

extension ServerClient {
    func fetchAccountActivity(cursor: String? = nil, expectedRevision: UUID? = nil) async throws -> ServerAccountActivityPage {
        try await request(.clientActivity(cursor: cursor, limit: 30),
                          expectedRevision: expectedRevision ?? sessionRevision)
    }
}
