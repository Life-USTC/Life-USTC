import SwiftUI

enum ServerCatalogKind: String, CaseIterable, Identifiable {
    case sections, courses, teachers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sections: String(localized: "Teaching Sections")
        case .courses: String(localized: "Courses")
        case .teachers: String(localized: "Teachers")
        }
    }
}

@Observable
@MainActor
final class ServerCatalogModel {
    var kind = ServerCatalogKind.sections
    var search = ""
    var semesterID: Int?
    var semesters: [ServerSemester] = []
    var sections: [ServerSectionSummary] = []
    var courses: [ServerCourseSummary] = []
    var teachers: [ServerTeacherSummary] = []
    var isLoading = false
    var error: String?
    var semesterError: String?
    var total = 0
    var hasMore = false

    private let client: ServerClient
    private var page = 0
    private var generation = 0

    init(client: ServerClient = .shared) {
        self.client = client
    }

    var requestID: String { "\(kind.rawValue)|\(search)|\(semesterID.map(String.init) ?? "all")" }

    var isEmpty: Bool {
        switch kind {
        case .sections: sections.isEmpty
        case .courses: courses.isEmpty
        case .teachers: teachers.isEmpty
        }
    }

    func loadSemesters() async {
        semesterError = nil
        do {
            let semesters = try await client.fetchAllSemesters()
            guard !Task.isCancelled else { return }
            self.semesters = semesters
        } catch {
            guard !Task.isCancelled else { return }
            semesterError = error.localizedDescription
        }
    }

    func load(append: Bool = false) async {
        if append && (isLoading || !hasMore) { return }
        generation += 1
        let requestGeneration = generation
        let nextPage = append ? page + 1 : 1
        let kind = kind
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let semesterID = semesterID
        isLoading = true
        error = nil
        if !append {
            sections = []
            courses = []
            teachers = []
            total = 0
            hasMore = false
        }
        defer {
            if requestGeneration == generation { isLoading = false }
        }
        do {
            let pagination: PaginationInfo
            switch kind {
            case .sections:
                let result = try await client.searchSections(
                    query: query.isEmpty ? nil : query, semesterId: semesterID,
                    page: nextPage, pageSize: 30
                )
                guard requestGeneration == generation, !Task.isCancelled else { return }
                sections = append ? sections + result.data : result.data
                pagination = result.pagination
            case .courses:
                let result = try await client.searchCourses(
                    query: query.isEmpty ? nil : query, page: nextPage, pageSize: 30
                )
                guard requestGeneration == generation, !Task.isCancelled else { return }
                courses = append ? courses + result.data : result.data
                pagination = result.pagination
            case .teachers:
                let result = try await client.searchTeachers(
                    query: query.isEmpty ? nil : query, page: nextPage, pageSize: 30
                )
                guard requestGeneration == generation, !Task.isCancelled else { return }
                teachers = append ? teachers + result.data : result.data
                pagination = result.pagination
            }
            page = pagination.page
            total = pagination.total
            hasMore = page < pagination.totalPages
        } catch {
            guard requestGeneration == generation, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}

struct ServerCatalogView: View {
    @State private var model = ServerCatalogModel()

    var body: some View {
        List {
            Section {
                Picker("Catalog", selection: $model.kind) {
                    ForEach(ServerCatalogKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("catalog_kind")

                if model.kind == .sections {
                    Picker("Semester", selection: $model.semesterID) {
                        Text("All semesters").tag(nil as Int?)
                        ForEach(model.semesters) { semester in
                            Text(semester.nameCn).tag(Optional(semester.id))
                        }
                    }
                    .accessibilityIdentifier("catalog_semester")
                }
            }

            if let error = model.semesterError, model.kind == .sections {
                Section {
                    Text(error).foregroundStyle(.secondary)
                    Button("Retry semesters") { Task { await model.loadSemesters() } }
                }
            }

            if let error = model.error {
                Section {
                    Text(error).foregroundStyle(.secondary)
                    Button("Retry") { Task { await model.load() } }
                        .accessibilityIdentifier("catalog_retry")
                }
            }

            if model.isEmpty && !model.isLoading && model.error == nil {
                ContentUnavailableView.search(text: model.search)
            }

            Section {
                switch model.kind {
                case .sections:
                    ForEach(model.sections) { section in
                        NavigationLink {
                            ServerSectionDetailView(jwId: section.jwId)
                        } label: {
                            ServerSectionRow(section: section)
                        }
                        .accessibilityIdentifier("catalog_section_\(section.jwId)")
                    }
                case .courses:
                    ForEach(model.courses) { course in
                        NavigationLink {
                            ServerCourseDetailView(jwId: course.jwId)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ServerCatalogDisplay.name(course.nameCn, course.nameEn))
                                Text(course.code).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("catalog_course_\(course.jwId)")
                    }
                case .teachers:
                    ForEach(model.teachers) { teacher in
                        NavigationLink {
                            ServerTeacherDetailView(id: teacher.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ServerCatalogDisplay.name(teacher.nameCn, teacher.nameEn))
                                if let department = teacher.department {
                                    Text(ServerCatalogDisplay.name(department.nameCn, department.nameEn))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityIdentifier("catalog_teacher_\(teacher.id)")
                    }
                }
            } footer: {
                if !model.isEmpty { Text("\(model.total) results") }
            }

            if model.isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if model.hasMore {
                Button("Load more") { Task { await model.load(append: true) } }
                    .accessibilityIdentifier("catalog_load_more")
            }
        }
        .navigationTitle("Catalog")
        .searchable(
            text: $model.search,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search catalog"
        )
        .task { await model.loadSemesters() }
        .task(id: model.requestID) {
            if !model.search.isEmpty {
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            }
            await model.load()
        }
        .refreshable { await model.load() }
    }
}

enum ServerCatalogDisplay {
    static func name(_ chinese: String, _ english: String?) -> String {
        if Locale.current.language.languageCode?.identifier == "en", let english, !english.isEmpty {
            return english
        }
        return chinese
    }

    static func time(_ value: IntOrString) -> String {
        let time = value.components
        return String(format: "%02d:%02d", time.hour, time.minute)
    }

    static func time(_ value: Int) -> String {
        String(format: "%02d:%02d", value / 100, value % 100)
    }
}

struct ServerSectionRow: View {
    let section: ServerSectionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(section.course.map { ServerCatalogDisplay.name($0.nameCn, $0.nameEn) } ?? section.code)
            Text(section.code).font(.caption).foregroundStyle(.secondary)
            if let semester = section.semester {
                Text(semester.nameCn).font(.caption).foregroundStyle(.secondary)
            }
            if let teachers = section.teachers, !teachers.isEmpty {
                Text(teachers.map { ServerCatalogDisplay.name($0.nameCn, $0.nameEn) }.joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
