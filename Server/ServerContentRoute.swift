import Foundation

enum ServerContentRoute: Hashable, Identifiable {
    case course(Int), section(Int), teacher(Int)
    case youngEvent(String), organizer(String), comment(String), publicProfile(String)
    case publication(String), publicationSources
    case todos, homeworks, exams, calendar

    var id: String { path }

    init?(url: URL, baseURL: URL) {
        let parts: [String]
        if url.scheme?.lowercased() == ServerAuth.callbackScheme {
            guard let host = url.host, host != "auth" else { return nil }
            parts = [host] + url.pathComponents.filter { $0 != "/" }
        } else {
            guard url.scheme?.lowercased() == baseURL.scheme?.lowercased(),
                  url.host?.lowercased() == baseURL.host?.lowercased(), url.port == baseURL.port else { return nil }
            parts = url.pathComponents.filter { $0 != "/" }
        }
        guard let identifier = parts.last else { return nil }
        switch parts.dropLast().joined(separator: "/") {
        case "catalog/courses":
            guard let id = Int(identifier), id > 0 else { return nil }; self = .course(id)
        case "catalog/sections":
            guard let id = Int(identifier), id > 0 else { return nil }; self = .section(id)
        case "catalog/teachers":
            guard let id = Int(identifier), id > 0 else { return nil }; self = .teacher(id)
        case "catalog/young-events/organizers": self = .organizer(identifier)
        case "catalog/young-events":
            guard !["calendar", "organizers"].contains(identifier) else { return nil }; self = .youngEvent(identifier)
        case "community/comments":
            guard identifier != "guide" else { return nil }; self = .comment(identifier)
        case "community/users": self = .publicProfile(identifier)
        case "news": self = identifier == "sources" ? .publicationSources : .publication(identifier)
        case "workspace":
            switch identifier {
            case "todos": self = .todos
            case "homeworks": self = .homeworks
            case "exams": self = .exams
            case "calendar": self = .calendar
            default: return nil
            }
        default: return nil
        }
    }

    func url(baseURL: URL) -> URL {
        baseURL.appendingPathComponent(path)
    }

    private var path: String {
        switch self {
        case .course(let id): "catalog/courses/\(id)"
        case .section(let id): "catalog/sections/\(id)"
        case .teacher(let id): "catalog/teachers/\(id)"
        case .youngEvent(let id): "catalog/young-events/\(id)"
        case .organizer(let id): "catalog/young-events/organizers/\(id)"
        case .comment(let id): "community/comments/\(id)"
        case .publicProfile(let id): "community/users/\(id)"
        case .publication(let id): "news/\(id)"
        case .publicationSources: "news/sources"
        case .todos: "workspace/todos"
        case .homeworks: "workspace/homeworks"
        case .exams: "workspace/exams"
        case .calendar: "workspace/calendar"
        }
    }
}
