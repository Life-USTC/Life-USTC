import SwiftUI

struct ServerSubscriptionSemesterGroup: Identifiable {
    let semester: ServerSemester?
    let sections: [ServerLearningSubscription]
    var id: Int { semester?.id ?? -1 }
}

extension ServerSubscriptionKind {
    static var catalogKinds: [Self] { [.regular, .auditor, .teachingAssistant] }

    var title: String {
        switch self {
        case .regular: String(localized: "Enrolled")
        case .auditor: String(localized: "Auditing")
        case .teachingAssistant: String(localized: "Teaching assistant")
        }
    }
}

@Observable
@MainActor
final class ServerSubscriptionsModel {
    var sections: [ServerLearningSubscription] = []
    var semesterID: Int?
    var isLoading = false
    var isSaving = false
    var error: String?

    private let client: ServerClient
    private var generation = 0
    private var loadedRevision: UUID?

    init(client: ServerClient = .shared) { self.client = client }

    var semesters: [ServerSemester] {
        var ids = Set<Int>()
        return sections.compactMap(\.semester).filter { ids.insert($0.id).inserted }
            .sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
    }

    var filteredSections: [ServerLearningSubscription] {
        guard let semesterID else { return sections }
        return sections.filter { $0.semester?.id == semesterID }
    }

    var groups: [ServerSubscriptionSemesterGroup] {
        let sections = filteredSections
        var result = semesters.compactMap { semester -> ServerSubscriptionSemesterGroup? in
            let matching = sections.filter { $0.semester?.id == semester.id }
            return matching.isEmpty ? nil : .init(semester: semester, sections: matching)
        }
        let unknown = sections.filter { $0.semester == nil }
        if !unknown.isEmpty { result.append(.init(semester: nil, sections: unknown)) }
        return result
    }

    func load() async {
        generation += 1
        let requestGeneration = generation
        let revision = client.sessionRevision
        sections = []
        loadedRevision = nil
        error = nil
        isLoading = client.isAuthenticated
        guard client.isAuthenticated else { return }
        defer {
            if generation == requestGeneration { isLoading = false }
        }
        do {
            let result = try await client.fetchLearningSubscriptions()
            guard requestGeneration == generation, revision == client.sessionRevision, !Task.isCancelled else { return }
            sections = result
            loadedRevision = revision
            if let semesterID, !semesters.contains(where: { $0.id == semesterID }) {
                self.semesterID = nil
            }
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }

    func setKind(_ kind: ServerSubscriptionKind, for section: ServerLearningSubscription) async {
        guard !isSaving, let revision = loadedRevision, revision == client.sessionRevision else { return }
        let requestGeneration = generation
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            try await client.updateSectionSubscriptionKind(jwID: section.jwId, kind: kind, expectedRevision: revision)
            guard requestGeneration == generation, revision == client.sessionRevision, !Task.isCancelled else { return }
            await load()
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }

    func remove(_ section: ServerLearningSubscription) async {
        guard !isSaving, let revision = loadedRevision, revision == client.sessionRevision else { return }
        let requestGeneration = generation
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            try await client.removeSectionSubscription(sectionID: section.id, expectedRevision: revision)
            guard requestGeneration == generation, revision == client.sessionRevision, !Task.isCancelled else { return }
            await load()
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}

struct ServerSubscriptionsView: View {
    @State private var model = ServerSubscriptionsModel()
    @Bindable private var account = ServerAccountStore.shared

    private var accountKey: String {
        "\(ServerClient.shared.baseURL.absoluteString)|\(account.user?.id ?? (account.isAuthenticated ? "signed-in" : "anonymous"))"
    }

    var body: some View {
        List {
            if !account.isAuthenticated {
                Section {
                    Text("Sign in to manage your section subscriptions.")
                    NavigationLink("Server Account") { ServerAccountView() }
                        .accessibilityIdentifier("subscriptions_sign_in")
                }
            } else {
                Section {
                    Picker("Semester", selection: $model.semesterID) {
                        Text("All semesters").tag(nil as Int?)
                        ForEach(model.semesters) { semester in
                            Text(ServerCatalogDisplay.semesterName(semester)).tag(Optional(semester.id))
                        }
                    }
                    .accessibilityIdentifier("subscriptions_semester")
                    NavigationLink("Find teaching sections") { ServerCatalogView() }
                    if !model.sections.isEmpty {
                        NavigationLink("Export section calendars") {
                            ServerMultiSectionCalendarView(sections: model.sections)
                        }
                        .accessibilityIdentifier("subscriptions_calendar_export")
                    }
                } footer: {
                    Text("Subscriptions organize your workspace and do not change official course enrollment.")
                }

                if let error = model.error {
                    Section {
                        Text(error).foregroundStyle(.secondary)
                        Button("Retry") { Task { await model.load() } }
                            .accessibilityIdentifier("subscriptions_retry")
                    }
                }

                ForEach(model.groups) { group in
                    Section {
                        ForEach(group.sections) { section in
                            NavigationLink {
                                ServerSectionDetailView(jwId: section.jwId)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(section.course.map { ServerCatalogDisplay.name($0.nameCn, $0.nameEn) } ?? section.code)
                                    Text(section.code).font(.caption.monospaced()).foregroundStyle(.secondary)
                                    if section.retiredAt != nil {
                                        Label("Historical section", systemImage: "clock.arrow.circlepath")
                                            .font(.caption).foregroundStyle(.secondary)
                                            .accessibilityIdentifier("subscription_historical_\(section.jwId)")
                                    }
                                    if let teachers = section.teachers, !teachers.isEmpty {
                                        Text(teachers.map { ServerCatalogDisplay.name($0.nameCn, $0.nameEn) }.joined(separator: ", "))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .accessibilityIdentifier("subscription_\(section.jwId)")
                            .swipeActions {
                                Button("Unsubscribe", role: .destructive) {
                                    Task { await model.remove(section) }
                                }
                                .disabled(model.isSaving)
                            }

                            Menu {
                                ForEach(ServerSubscriptionKind.catalogKinds, id: \.self) { kind in
                                    Button(kind.title) { Task { await model.setKind(kind, for: section) } }
                                        .accessibilityIdentifier("subscription_kind_\(kind.rawValue)")
                                }
                            } label: {
                                LabeledContent("Subscription role", value: section.kind.title)
                            }
                            .disabled(model.isSaving)
                            .accessibilityIdentifier("subscription_kind_\(section.jwId)")
                        }
                    } header: {
                        Text("\(group.semester.map { ServerCatalogDisplay.semesterName($0) } ?? "Semester unavailable".localized) · \(group.sections.count)")
                    }
                }

                if model.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if model.filteredSections.isEmpty && model.error == nil {
                    ContentUnavailableView(
                        "No section subscriptions", systemImage: "books.vertical",
                        description: Text("Find a teaching section to add its schedule and exams to your workspace.")
                    )
                }
            }
        }
        .navigationTitle("Section Subscriptions")
        .task(id: accountKey) { await model.load() }
        .refreshable { await model.load() }
    }
}
