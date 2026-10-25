import SwiftUI

@Observable
@MainActor
final class ServerSectionDetailModel {
    let jwId: Int
    var section: ServerSectionDetail?
    var schedules: [ServerScheduleEntry] = []
    var subscription: ServerLearningSubscription?
    var isLoading = false
    var isSaving = false
    var error: String?
    var scheduleError: String?
    var subscriptionError: String?
    var subscriptionReadSucceeded = false

    private let client: ServerClient
    private var generation = 0
    private var subscriptionRevision: UUID?

    init(jwId: Int, client: ServerClient = .shared) {
        self.jwId = jwId
        self.client = client
    }

    func load() async {
        generation += 1
        let requestGeneration = generation
        section = nil
        schedules = []
        subscription = nil
        subscriptionRevision = nil
        subscriptionReadSucceeded = false
        error = nil
        scheduleError = nil
        subscriptionError = nil
        isLoading = true
        defer { if generation == requestGeneration { isLoading = false } }
        do {
            let section = try await client.fetchSectionDetail(jwId: String(jwId))
            guard requestGeneration == generation, !Task.isCancelled else { return }
            self.section = section
        } catch {
            guard requestGeneration == generation, !Task.isCancelled else { return }
            self.error = error.localizedDescription
            return
        }
        do {
            let schedules = try await client.fetchAllSectionSchedules(jwID: jwId)
            guard requestGeneration == generation, !Task.isCancelled else { return }
            self.schedules = schedules
        } catch {
            guard requestGeneration == generation, !Task.isCancelled else { return }
            scheduleError = error.localizedDescription
        }
        await loadSubscription(generation: requestGeneration)
    }

    func toggleSubscription() async {
        guard !isSaving, subscriptionReadSucceeded, let section,
              let revision = subscriptionRevision, revision == client.sessionRevision else { return }
        guard subscription != nil || section.retiredAt == nil else { return }
        let requestGeneration = generation
        isSaving = true
        subscriptionError = nil
        defer { isSaving = false }
        do {
            if subscription == nil {
                try await client.appendSectionSubscription(sectionID: section.id, expectedRevision: revision)
            } else {
                try await client.removeSectionSubscription(sectionID: section.id, expectedRevision: revision)
            }
            guard requestGeneration == generation, revision == client.sessionRevision, !Task.isCancelled else { return }
            await loadSubscription(generation: requestGeneration)
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision, !Task.isCancelled else { return }
            subscriptionError = error.localizedDescription
        }
    }

    func setKind(_ kind: ServerSubscriptionKind) async {
        guard !isSaving, subscriptionReadSucceeded, subscription != nil,
              let revision = subscriptionRevision, revision == client.sessionRevision else { return }
        let requestGeneration = generation
        isSaving = true
        subscriptionError = nil
        defer { isSaving = false }
        do {
            try await client.updateSectionSubscriptionKind(jwID: jwId, kind: kind, expectedRevision: revision)
            guard requestGeneration == generation, revision == client.sessionRevision, !Task.isCancelled else { return }
            await loadSubscription(generation: requestGeneration)
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision, !Task.isCancelled else { return }
            subscriptionError = error.localizedDescription
        }
    }

    private func loadSubscription(generation requestGeneration: Int) async {
        guard client.isAuthenticated else { return }
        let revision = client.sessionRevision
        subscriptionReadSucceeded = false
        do {
            let sections = try await client.fetchLearningSubscriptions()
            guard requestGeneration == generation, revision == client.sessionRevision, !Task.isCancelled else { return }
            subscription = sections.first { $0.jwId == jwId }
            subscriptionRevision = revision
            subscriptionReadSucceeded = true
            subscriptionError = nil
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision, !Task.isCancelled else { return }
            subscriptionError = error.localizedDescription
        }
    }
}

struct ServerSectionDetailView: View {
    @State private var model: ServerSectionDetailModel
    @Bindable private var account = ServerAccountStore.shared

    init(jwId: Int) {
        _model = State(initialValue: ServerSectionDetailModel(jwId: jwId))
    }

    private var accountKey: String {
        "\(ServerClient.shared.baseURL.absoluteString)|\(account.user?.id ?? (account.isAuthenticated ? "signed-in" : "anonymous"))"
    }

    var body: some View {
        List {
            if let error = model.error {
                Section {
                    Text(error).foregroundStyle(.secondary)
                    Button("Retry") { Task { await model.load() } }
                }
            }

            if let section = model.section {
                Section {
                    if let course = section.course {
                        Text(ServerCatalogDisplay.name(course.nameCn, course.nameEn)).font(.title2.bold())
                        NavigationLink("Course details") { ServerCourseDetailView(jwId: course.jwId) }
                    }
                    LabeledContent("Section code", value: section.code)
                    if let semester = section.semester { LabeledContent("Semester", value: ServerCatalogDisplay.semesterName(semester)) }
                    if section.retiredAt != nil {
                        Label("Historical section", systemImage: "clock.arrow.circlepath")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("section_historical")
                    }
                    if let campus = section.campus {
                        LabeledContent("Campus", value: ServerCatalogDisplay.name(campus.nameCn, campus.nameEn))
                    }
                    if let credits = section.credits { LabeledContent("Credits", value: credits.formatted()) }
                }

                Section {
                    if account.isAuthenticated {
                        if let subscription = model.subscription {
                            Menu {
                                ForEach(ServerSubscriptionKind.catalogKinds, id: \.self) { kind in
                                    Button(kind.title) { Task { await model.setKind(kind) } }
                                        .accessibilityIdentifier("subscription_kind_\(kind.rawValue)")
                                }
                            } label: {
                                LabeledContent("Subscription role", value: subscription.kind.title)
                            }
                            .disabled(model.isSaving || !model.subscriptionReadSucceeded)
                            .accessibilityIdentifier("section_kind")
                            Button("Unsubscribe", role: .destructive) {
                                Task { await model.toggleSubscription() }
                            }
                            .disabled(model.isSaving || !model.subscriptionReadSucceeded)
                            .accessibilityIdentifier("section_unsubscribe")
                        } else if section.retiredAt == nil {
                            Button("Subscribe") { Task { await model.toggleSubscription() } }
                                .disabled(model.isSaving || !model.subscriptionReadSucceeded)
                                .accessibilityIdentifier("section_subscribe")
                        }
                        if model.isSaving { ProgressView() }
                        if let error = model.subscriptionError {
                            Text(error).foregroundStyle(.red)
                            if !model.subscriptionReadSucceeded {
                                Button("Retry") { Task { await model.load() } }
                            }
                        }
                    } else if section.retiredAt == nil {
                        NavigationLink("Sign in to subscribe") { ServerAccountView() }
                            .accessibilityIdentifier("section_sign_in")
                    }
                } footer: {
                    Text("Subscriptions organize your workspace and do not change official course enrollment.")
                }

                if let teachers = section.teachers, !teachers.isEmpty {
                    Section("Teachers") {
                        ForEach(teachers) { teacher in
                            NavigationLink(ServerCatalogDisplay.name(teacher.nameCn, teacher.nameEn)) {
                                ServerTeacherDetailView(id: teacher.id)
                            }
                            NavigationLink {
                                ScrollView {
                                    CommentListView(viewModel: CommentListViewModel(
                                        targetType: "section-teacher", sectionId: section.id, teacherId: teacher.id
                                    ))
                                }
                                .navigationTitle("Teaching feedback")
                            } label: {
                                Label(String(format: "Feedback for %@".localized,
                                             ServerCatalogDisplay.name(teacher.nameCn, teacher.nameEn)),
                                      systemImage: "bubble.left.and.bubble.right")
                            }
                        }
                    }
                }

                Section("Schedule") {
                    NavigationLink("Export section calendar") {
                        ServerSectionCalendarView(sectionJWID: section.jwId)
                    }
                    .accessibilityIdentifier("section_calendar_export")
                    if let error = model.scheduleError {
                        Text(error).foregroundStyle(.secondary)
                        Button("Retry") { Task { await model.load() } }
                    } else if model.schedules.isEmpty && !model.isLoading {
                        Text("No published schedule").foregroundStyle(.secondary)
                    }
                    ForEach(model.schedules) { schedule in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(schedule.date.map { String($0.prefix(10)) } ?? String(localized: "Date unavailable"))
                            Text("\(ServerCatalogDisplay.time(schedule.startTime)) – \(ServerCatalogDisplay.time(schedule.endTime))")
                            if let week = schedule.weekIndex {
                                Text(String(format: "Week %lld".localized, Int64(week))).font(.caption)
                            }
                            if let place = schedule.customPlace ?? schedule.room?.namePrimary ?? schedule.room?.name ?? schedule.room?.code {
                                Label(place, systemImage: "mappin.and.ellipse").font(.caption)
                            }
                            if let building = schedule.room?.building {
                                if let name = building.namePrimary ?? building.name ?? building.code {
                                    Label(name, systemImage: "building.2").font(.caption)
                                }
                                if let campus = building.campus {
                                    Text(ServerCatalogDisplay.name(campus.nameCn, campus.nameEn)).font(.caption)
                                }
                            }
                        }
                        .accessibilityIdentifier("section_schedule_\(schedule.id)")
                        ForEach(schedule.teachers ?? []) { teacher in
                            NavigationLink {
                                ServerTeacherDetailView(id: teacher.id)
                            } label: {
                                Label(ServerCatalogDisplay.name(teacher.nameCn, teacher.nameEn), systemImage: "person")
                            }
                            .accessibilityIdentifier("section_schedule_\(schedule.id)_teacher_\(teacher.id)")
                        }
                    }
                }

                Section("Exams") {
                    if let exams = section.exams, !exams.isEmpty {
                        ForEach(exams) { exam in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exam.examDate ?? String(localized: "Date unavailable"))
                                if let start = exam.startTime, let end = exam.endTime {
                                    Text("\(ServerCatalogDisplay.time(start)) – \(ServerCatalogDisplay.time(end))")
                                }
                                let rooms = exam.examRooms?.compactMap(\.room).joined(separator: ", ") ?? ""
                                if !rooms.isEmpty { Label(rooms, systemImage: "mappin.and.ellipse").font(.caption) }
                            }
                        }
                    } else {
                        Text("No published exams").foregroundStyle(.secondary)
                    }
                }

                Section {
                    NavigationLink("Description") {
                        ServerDescriptionView(target: .section(jwId: section.jwId))
                    }
                    .accessibilityIdentifier("section_description")
                    NavigationLink("Shared Homework") {
                        ServerSectionHomeworksView(sectionJwId: section.jwId)
                    }
                    .accessibilityIdentifier("section_homeworks")
                    NavigationLink("Comments") {
                        ScrollView {
                            CommentListView(viewModel: CommentListViewModel(targetType: "section", targetId: String(section.id)))
                        }
                        .navigationTitle("Comments")
                    }
                }
            }
            if model.isLoading { ProgressView().frame(maxWidth: .infinity) }
        }
        .navigationTitle(model.section?.code ?? String(localized: "Teaching Section"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ServerContentShareButton(route: .section(model.jwId)) }
        .task(id: accountKey) { await model.load() }
        .refreshable { await model.load() }
    }
}

@Observable
@MainActor
final class ServerCatalogSectionsModel {
    private(set) var isLoading = false
    private(set) var error: String?

    private let client: ServerClient
    private var snapshot: [ServerSectionSummary] = []
    private var loadedRevision: UUID?
    private var scope: ServerCatalogSectionScope?
    private var generation = 0

    init(client: ServerClient = .shared) { self.client = client }

    var sections: [ServerSectionSummary] {
        loadedRevision == client.sessionRevision ? snapshot : []
    }

    func load(scope: ServerCatalogSectionScope) async {
        generation += 1
        let requestGeneration = generation
        let revision = client.sessionRevision
        if self.scope != scope || loadedRevision != revision {
            snapshot = []
            self.scope = scope
            loadedRevision = revision
        }
        error = nil
        isLoading = true
        defer { if requestGeneration == generation { isLoading = false } }
        do {
            let result = try await client.fetchAllCatalogSections(scope: scope)
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            snapshot = result
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, revision == client.sessionRevision,
                  !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}

struct ServerCourseDetailView: View {
    let jwId: Int
    @State private var course: ServerCourseDetail?
    @State private var sectionList = ServerCatalogSectionsModel()
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        List {
            if let error {
                Text(error).foregroundStyle(.secondary)
                Button("Retry") { Task { await load() } }
            }
            if let course {
                Section {
                    Text(ServerCatalogDisplay.name(course.nameCn, course.nameEn)).font(.title2.bold())
                    LabeledContent("Course code", value: course.code)
                    if let category = course.category {
                        LabeledContent("Category", value: ServerCatalogDisplay.name(category.nameCn, category.nameEn))
                    }
                    if let level = course.educationLevel {
                        LabeledContent("Education level", value: ServerCatalogDisplay.educationLevelName(level))
                    }
                }
                Section("Teaching Sections") {
                    if let error = sectionList.error {
                        Text(error).foregroundStyle(.secondary)
                        Button("Retry") { Task { await sectionList.load(scope: .course(course.jwId)) } }
                            .accessibilityIdentifier("course_sections_retry")
                    }
                    ForEach(sectionList.sections) { section in
                        NavigationLink {
                            ServerSectionDetailView(jwId: section.jwId)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(section.code)
                                if section.retiredAt != nil {
                                    Label("Historical section", systemImage: "clock.arrow.circlepath")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                if let semester = section.semester {
                                    Text(ServerCatalogDisplay.semesterName(semester)).font(.caption).foregroundStyle(.secondary)
                                }
                                if let teachers = section.teachers {
                                    Text(teachers.map { ServerCatalogDisplay.name($0.nameCn, $0.nameEn) }.joined(separator: ", "))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityIdentifier("catalog_section_\(section.jwId)")
                    }
                    if sectionList.isLoading {
                        ProgressView()
                    } else if sectionList.sections.isEmpty && sectionList.error == nil {
                        Text("No teaching sections").foregroundStyle(.secondary)
                    }
                }
                Section {
                    NavigationLink("Description") {
                        ServerDescriptionView(target: .course(jwId: course.jwId))
                    }
                    NavigationLink("Comments") {
                        ScrollView {
                            CommentListView(viewModel: CommentListViewModel(targetType: "course", courseJwId: course.jwId))
                        }
                        .navigationTitle("Comments")
                    }
                }
            }
            if isLoading { ProgressView().frame(maxWidth: .infinity) }
        }
        .navigationTitle("Course details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ServerContentShareButton(route: .course(jwId)) }
        .task { await load() }
        .refreshable { await load() }
    }

    @MainActor
    private func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let result = try await ServerClient.shared.fetchCourseDetail(jwId: String(jwId))
            guard !Task.isCancelled else { return }
            course = result
            isLoading = false
            await sectionList.load(scope: .course(result.jwId))
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}

struct ServerTeacherDetailView: View {
    let id: Int
    @State private var teacher: ServerTeacherDetail?
    @State private var sectionList = ServerCatalogSectionsModel()
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        List {
            if let error {
                Text(error).foregroundStyle(.secondary)
                Button("Retry") { Task { await load() } }
            }
            if let teacher {
                Section {
                    Text(ServerCatalogDisplay.name(teacher.nameCn, teacher.nameEn)).font(.title2.bold())
                    if let department = teacher.department {
                        LabeledContent("Department", value: ServerCatalogDisplay.name(department.nameCn, department.nameEn))
                    }
                    if let title = teacher.teacherTitle {
                        LabeledContent("Title", value: ServerCatalogDisplay.name(title.nameCn, title.nameEn))
                    }
                    if let email = teacher.email, let url = URL(string: "mailto:\(email)") {
                        Link(email, destination: url)
                    }
                    if let address = teacher.address, !address.isEmpty { LabeledContent("Address", value: address) }
                    if let telephone = teacher.telephone, !telephone.isEmpty { LabeledContent("Telephone", value: telephone) }
                    if let mobile = teacher.mobile, !mobile.isEmpty { LabeledContent("Mobile", value: mobile) }
                }
                Section("Teaching Sections") {
                    if let error = sectionList.error {
                        Text(error).foregroundStyle(.secondary)
                        Button("Retry") { Task { await sectionList.load(scope: .teacher(teacher.id)) } }
                            .accessibilityIdentifier("teacher_sections_retry")
                    }
                    ForEach(sectionList.sections) { section in
                        NavigationLink {
                            ServerSectionDetailView(jwId: section.jwId)
                        } label: {
                            ServerSectionRow(section: section)
                        }
                        .accessibilityIdentifier("catalog_section_\(section.jwId)")
                    }
                    if sectionList.isLoading {
                        ProgressView()
                    } else if sectionList.sections.isEmpty && sectionList.error == nil {
                        Text("No teaching sections").foregroundStyle(.secondary)
                    }
                }
                Section {
                    NavigationLink("Description") {
                        ServerDescriptionView(target: .teacher(id: teacher.id))
                    }
                    .accessibilityIdentifier("teacher_description")
                }
                Section {
                    NavigationLink("Comments") {
                        ScrollView {
                            CommentListView(viewModel: CommentListViewModel(targetType: "teacher", teacherId: teacher.id))
                        }
                        .navigationTitle("Comments")
                    }
                }
            }
            if isLoading { ProgressView().frame(maxWidth: .infinity) }
        }
        .navigationTitle("Teacher details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ServerContentShareButton(route: .teacher(id)) }
        .task { await load() }
        .refreshable { await load() }
    }

    @MainActor
    private func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let result = try await ServerClient.shared.fetchTeacherDetail(id: id)
            guard !Task.isCancelled else { return }
            teacher = result
            isLoading = false
            await sectionList.load(scope: .teacher(result.id))
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}
