import Foundation

enum ServerWebLinks {
    static func workspaceSearch(_ query: String, baseURL: URL) -> URL {
        var url = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        url.queryItems = [.init(name: "q", value: query)]
        return url.url!
    }

    static func campusLink(_ slug: String, baseURL: URL) -> URL {
        var url = URLComponents(url: baseURL.appendingPathComponent("api/catalog/links/resolve"), resolvingAgainstBaseURL: false)!
        url.queryItems = [.init(name: "slug", value: slug)]
        return url.url!
    }
}
