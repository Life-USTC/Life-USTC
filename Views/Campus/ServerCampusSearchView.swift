import SwiftUI

enum ServerCampusSearchDestination: Equatable {
    case course(Int), section(Int), teacher(Int), external(URL)

    init?(item: ServerGlobalSearchResponse.Item, group: String) {
        if group == "links", let url = URL(string: item.href) {
            self = .external(url)
            return
        }
        let parts = item.id.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, let id = Int(parts[1]) else { return nil }
        switch (group, parts[0]) {
        case ("courses", "course"): self = .course(id)
        case ("sections", "section"): self = .section(id)
        case ("teachers", "teacher"): self = .teacher(id)
        default: return nil
        }
    }
}

@MainActor @Observable
final class ServerCampusSearchModel {
    private let client: ServerClient
    private(set) var result: ServerGlobalSearchResponse?
    private(set) var isLoading = false
    private(set) var error: String?
    private var activeQuery = ""

    init(client: ServerClient = .shared) { self.client = client }

    func search(_ query: String, locale: String) async {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        activeQuery = query
        result = nil
        error = nil
        guard query.utf16.count >= 2, query.utf16.count <= 200 else { isLoading = false; return }
        isLoading = true
        defer { if activeQuery == query { isLoading = false } }
        do {
            let value = try await client.searchCampus(query: query, locale: locale)
            guard activeQuery == query, !Task.isCancelled else { return }
            result = value
        } catch is CancellationError { return }
        catch { if activeQuery == query, !Task.isCancelled { self.error = error.localizedDescription } }
    }
}

struct ServerCampusSearchView: View {
    @Environment(\.locale) private var locale
    @State private var query = ""
    @State private var model = ServerCampusSearchModel()

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        List {
            if trimmedQuery.utf16.count < 2 {
                ContentUnavailableView("Search Campus", systemImage: "magnifyingglass",
                                       description: Text("Enter at least two characters to search courses, sections, teachers, and campus links."))
            } else if trimmedQuery.utf16.count > 200 {
                Text("Use a search query of at most 200 characters.").foregroundStyle(.secondary)
            } else {
                if model.isLoading { ProgressView("Searching campus…") }
                if let error = model.error { CampusErrorRow(message: error) { await model.search(query, locale: campusAPILocale(locale)) } }
                if let result = model.result, result.query == trimmedQuery {
                    ForEach(result.groups.filter { !$0.items.isEmpty }) { group in
                        Section {
                            ForEach(group.items) { item in resultRow(item, group: group.type) }
                        } header: {
                            Text(groupTitle(group.type))
                        }
                    }
                    if result.groups.allSatisfy({ $0.items.isEmpty }) { ContentUnavailableView.search(text: query) }
                    if result.groups.contains(where: { $0.items.count == 25 }) {
                        Section {
                            Text("Search shows up to 25 matches per category. Refine your query for more specific results.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section {
                Link("Search my workspace on the website",
                     destination: ServerWebLinks.workspaceSearch(trimmedQuery, baseURL: ServerClient.shared.baseURL))
                    .accessibilityIdentifier("search_workspace_web")
            } footer: {
                Text("Workspace search uses the account signed in on the website.")
            }
            Section {
                NavigationLink { ServerCatalogView() } label: { Label("Course catalog", systemImage: "books.vertical") }
            }
        }
        .navigationTitle("Search Campus")
        .searchable(text: $query, prompt: "Courses, teachers, and campus links")
        .task(id: "\(query):\(locale.identifier)") {
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            await model.search(query, locale: campusAPILocale(locale))
        }
    }

    @ViewBuilder
    private func resultRow(_ item: ServerGlobalSearchResponse.Item, group: String) -> some View {
        switch ServerCampusSearchDestination(item: item, group: group) {
        case .course(let id): NavigationLink { ServerCourseDetailView(jwId: id) } label: { resultLabel(item) }
        case .section(let id): NavigationLink { ServerSectionDetailView(jwId: id) } label: { resultLabel(item) }
        case .teacher(let id): NavigationLink { ServerTeacherDetailView(id: id) } label: { resultLabel(item) }
        case .external(let url): Link(destination: url) { resultLabel(item) }
        case nil: resultLabel(item)
        }
    }

    private func resultLabel(_ item: ServerGlobalSearchResponse.Item) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.title).foregroundStyle(.primary)
            if let code = item.code { Text(code).font(.caption).foregroundStyle(.secondary) }
            if let description = item.description, !description.isEmpty {
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("campus_search_\(item.id)")
    }

    private func groupTitle(_ type: String) -> String {
        switch type {
        case "courses": "Courses".localized
        case "sections": "Sections".localized
        case "teachers": "Teachers".localized
        default: "Campus Links".localized
        }
    }
}
