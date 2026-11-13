import Foundation

enum ServerContentRoute: Hashable, Identifiable {
    case course(Int), section(Int), teacher(Int)
    case youngEvent(String), organizer(String), comment(String), publicProfile(String)
    case publication(String), publicationSources
    case todos, homeworks, exams, calendar
    case workspace, campus, catalog, activities, activityCalendar, organizers, subscriptions
    case activitySubscriptions, organizerFollows, notifications

    enum PrimaryDestination: Hashable { case workspace, calendar, campus, activities }

    var primaryDestination: PrimaryDestination {
        switch self {
        case .workspace, .todos, .homeworks, .exams, .subscriptions,
             .activitySubscriptions, .organizerFollows, .notifications: .workspace
        case .calendar: .calendar
        case .activities, .activityCalendar, .organizers, .youngEvent, .organizer: .activities
        case .campus, .catalog, .course, .section, .teacher, .comment, .publicProfile,
             .publication, .publicationSources: .campus
        }
    }

    var opensPrimaryRoot: Bool {
        switch self {
        case .workspace, .campus, .activities, .calendar: true
        default: false
        }
    }

    var id: String { path + (activityView.map { "?view=\($0)" } ?? "") }

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
        // New root matches must not discard a web filter or date/view state.
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let plainRoot = query.isEmpty && url.fragment == nil
        let rootPath = parts.joined(separator: "/")
        if plainRoot {
            switch rootPath {
            case "", "workspace": self = .workspace; return
            case "campus": self = .campus; return
            case "catalog": self = .catalog; return
            case "catalog/young-events": self = .activities; return
            case "catalog/young-events/calendar": self = .activityCalendar; return
            case "catalog/young-events/organizers": self = .organizers; return
            case "workspace/subscriptions", "workspace/subscriptions/sections": self = .subscriptions; return
            default: break
            }
        }
        if rootPath == "workspace/subscriptions/activities" {
            guard url.fragment == nil, query.count <= 1,
                  query.allSatisfy({ $0.name == "view" }) else { return nil }
            let view = query.isEmpty ? "events" : (query[0].value ?? "")
            guard !view.isEmpty else { return nil }
            switch view {
            case "events": self = .activitySubscriptions
            case "organizers": self = .organizerFollows
            case "notifications": self = .notifications
            default: return nil
            }
            return
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
        let url = baseURL.appendingPathComponent(path)
        guard let activityView else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [.init(name: "view", value: activityView)]
        return components.url!
    }

    private var activityView: String? {
        switch self {
        case .organizerFollows: "organizers"
        case .notifications: "notifications"
        default: nil
        }
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
        case .workspace: "workspace"
        case .campus: "campus"
        case .catalog: "catalog"
        case .activities: "catalog/young-events"
        case .activityCalendar: "catalog/young-events/calendar"
        case .organizers: "catalog/young-events/organizers"
        case .subscriptions: "workspace/subscriptions"
        case .activitySubscriptions, .organizerFollows, .notifications: "workspace/subscriptions/activities"
        }
    }
}
