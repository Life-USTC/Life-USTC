import Foundation

enum ServerPublicationType: String, Codable, CaseIterable {
    case news, notice

    var title: String { self == .news ? "News" : "Notices" }
}

enum ServerPublicationOrganizationLevel: String, CaseIterable, Codable {
    case university, office, department, college, center, research
    case service, program, society, journal, student, unknown

    var title: String {
        switch self {
        case .university: "University"
        case .office: "Offices"
        case .department: "Departments"
        case .college: "Colleges"
        case .center: "Centers"
        case .research: "Research institutes"
        case .service: "Services"
        case .program: "Programs"
        case .society: "Societies"
        case .journal: "Journals"
        case .student: "Student organizations"
        case .unknown: "Other sources"
        }
    }
}

struct ServerPublicationFilters: Equatable {
    var type: ServerPublicationType?
    var sources: [String] = []
    var organizationLevels: [ServerPublicationOrganizationLevel] = []
    var query = ""
    var fold = false

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let type { items.append(.init(name: "type", value: type.rawValue)) }
        if !sources.isEmpty { items.append(.init(name: "source", value: sources.joined(separator: ","))) }
        if !organizationLevels.isEmpty {
            items.append(.init(name: "organizationLevel", value: organizationLevels.map(\.rawValue).joined(separator: ",")))
        }
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !search.isEmpty { items.append(.init(name: "query", value: search)) }
        if fold { items.append(.init(name: "fold", value: "1")) }
        return items
    }
}

struct ServerPublicationSource: Codable, Identifiable {
    let id: String
    let name: String
    let organizationLevel: String

    var knownOrganizationLevel: ServerPublicationOrganizationLevel {
        ServerPublicationOrganizationLevel(rawValue: organizationLevel) ?? .unknown
    }
}

struct ServerPublicationSourceSummary: Codable, Identifiable {
    let id: String
    let name: String
    let organizationLevel: String
    let hosts: [String]
    let publicationCount: Int
    let lastPublishedAt: Date?
}

struct ServerPublicationSourceGroup: Codable, Identifiable {
    let organizationLevel: String
    let sourceCount: Int
    let publicationCount: Int
    let sources: [ServerPublicationSourceSummary]

    var id: String { organizationLevel }
    var knownOrganizationLevel: ServerPublicationOrganizationLevel {
        ServerPublicationOrganizationLevel(rawValue: organizationLevel) ?? .unknown
    }
}

struct ServerPublicationSourceDirectory: Codable {
    struct Totals: Codable {
        let sourceCount: Int
        let publicationCount: Int
    }

    let groups: [ServerPublicationSourceGroup]
    let totals: Totals
}

enum ServerPublicationObjectKind: String, Codable {
    case bodyHTML = "body_html"
    case bodyMarkdown = "body_markdown"
    case media, asset
    case rawPage = "raw_page"
}

struct ServerPublicationObject: Codable, Identifiable {
    let kind: ServerPublicationObjectKind
    let sha256: String
    let size: Int
    let contentType: String
    let status: String
    let url: String
    let sortOrder: Int?
    let altText: String?
    let filename: String?
    let sourceUrl: String?

    var id: String { "\(kind.rawValue):\(sha256)" }
}

struct ServerPublicationImage: Codable, Identifiable {
    let id: String
    let url: String
    let altText: String?
    let title: String?
    let caption: String?
}

struct ServerPublicationRevision: Codable {
    let id: String
    let revisionHash: String
    let observedAt: Date
    let title: String
    let author: String?
    let reporter: String?
    let editor: String?
    let originalPublisher: String?
    let publishedAt: Date?
    let updatedAtSource: Date?
    let category: String?
    let summary: String?
    let sourcePageUrl: String?
    let images: [ServerPublicationImage]?
    let bodyText: String?
    let bodyMarkdown: String?
    let extractionMethod: String?
    let classifierVersion: String?
    let objects: [ServerPublicationObject]?
}

struct ServerPublicationListItem: Codable, Identifiable {
    struct FoldGroup: Codable { let siblingCount: Int }

    let id: String
    let canonicalUrl: String
    let publicationType: ServerPublicationType
    let source: ServerPublicationSource
    let revision: ServerPublicationRevision
    let objects: [ServerPublicationObject]
    let foldGroup: FoldGroup?
}

struct ServerPublicationSibling: Codable, Identifiable {
    let id: String
    let canonicalUrl: String
    let source: ServerPublicationSource
    let publishedAt: Date?
}

struct ServerPublicationDetail: Codable, Identifiable {
    let id: String
    let canonicalUrl: String
    let publicationType: ServerPublicationType
    let source: ServerPublicationSource
    let revision: ServerPublicationRevision
    let alsoPublishedIn: [ServerPublicationSibling]
}
