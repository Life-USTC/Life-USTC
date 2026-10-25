import SwiftUI

struct ServerWorkspaceExamsView: View {
    @State private var model = ServerWorkspaceExamsModel()
    @Bindable private var account = ServerAccountStore.shared

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            List {
                if !account.isAuthenticated {
                    ContentUnavailableView("Sign In Required", systemImage: "person.crop.circle",
                                           description: Text("Sign in to view exams for your subscriptions."))
                    NavigationLink("Sign In") { ServerAccountView() }
                } else {
                    Picker("Semester", selection: $model.semesterID) {
                        Text("All semesters").tag(Optional<Int>.none)
                        ForEach(model.semesters) { semester in
                            Text(semester.nameCn).tag(Optional(semester.id))
                        }
                    }
                    .accessibilityIdentifier("workspace.exams.semester")

                    if let error = model.error {
                        Section {
                            Text(error).foregroundStyle(.red)
                            Button("Retry") { Task { await model.load() } }
                                .accessibilityIdentifier("workspace.exams.retry")
                        }
                    }
                    if model.exams.isEmpty && !model.isLoading && model.error == nil {
                        ContentUnavailableView("No Exams", systemImage: "graduationcap",
                                               description: Text("No exams are published for these subscriptions."))
                    }
                    examSection("Upcoming exams", exams: model.exams.filter { $0.examDate != nil && !$0.isPast(at: context.date) })
                    examSection("Date unavailable", exams: model.exams.filter { $0.examDate == nil })
                    examSection("Past exams", exams: model.exams.filter { $0.isPast(at: context.date) })
                }
            }
        }
        .navigationTitle("Exams")
        .accessibilityIdentifier("workspace.exams.list")
        .environment(\.timeZone, YoungCalendarDate.shanghai)
        .environment(\.calendar, YoungCalendarDate.calendar)
        .task(id: account.sessionRevision) { await model.load() }
        .refreshable { await model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .serverSubscriptionsDidChange)) { _ in
            Task { await model.load() }
        }
        .overlay { if model.isLoading && model.exams.isEmpty { ProgressView() } }
    }

    @ViewBuilder
    private func examSection(_ title: LocalizedStringKey, exams: [ServerWorkspaceExam]) -> some View {
        if !exams.isEmpty {
            Section(title) {
                ForEach(exams) { exam in
                    NavigationLink {
                        ServerWorkspaceExamDetailView(examID: exam.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(ServerCatalogDisplay.name(exam.section.course.nameCn, exam.section.course.nameEn))
                                .font(.headline)
                            Text(exam.section.code).font(.caption).foregroundStyle(.secondary)
                            if let semester = exam.section.semester {
                                Text(ServerCatalogDisplay.semesterName(semester))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            ServerWorkspaceExamTimeView(exam: exam)
                            let rooms = exam.examRooms.compactMap(\.room).joined(separator: ", ")
                            if !rooms.isEmpty { Label(rooms, systemImage: "mappin.and.ellipse").font(.caption) }
                        }
                    }
                    .accessibilityIdentifier("workspace.exam.\(exam.id)")
                }
            }
        }
    }
}

struct ServerWorkspaceExamDetailView: View {
    let examID: Int
    @State private var model = ServerWorkspaceExamsModel()
    @Bindable private var account = ServerAccountStore.shared

    var body: some View {
        List {
            if !account.isAuthenticated {
                ContentUnavailableView("Sign In Required", systemImage: "person.crop.circle",
                                       description: Text("Sign in to view exams for your subscriptions."))
                NavigationLink("Sign In") { ServerAccountView() }
            } else {
                if let error = model.error {
                    Section {
                        Text(error).foregroundStyle(.red)
                        Button("Retry") { Task { await model.load() } }
                            .accessibilityIdentifier("workspace.exam.detail.retry")
                    }
                }
                if let exam = model.exam(id: examID) {
                    Section {
                        Text(ServerCatalogDisplay.name(exam.section.course.nameCn, exam.section.course.nameEn))
                            .font(.title2.bold())
                        ServerWorkspaceExamTimeView(exam: exam)
                        if let batch = exam.examBatch {
                            LabeledContent("Exam batch", value: ServerCatalogDisplay.name(batch.nameCn, batch.nameEn))
                        }
                        if let mode = exam.examMode, !mode.isEmpty { LabeledContent("Exam mode", value: mode) }
                    }
                    Section("Location") {
                        let rooms = exam.examRooms.compactMap(\.room).joined(separator: ", ")
                        if rooms.isEmpty { Text("Room unavailable").foregroundStyle(.secondary) }
                        else { Label(rooms, systemImage: "mappin.and.ellipse") }
                    }
                    Section {
                        if let semester = exam.section.semester { LabeledContent("Semester", value: semester.nameCn) }
                        NavigationLink(exam.section.code) { ServerSectionDetailView(jwId: exam.section.jwId) }
                            .accessibilityIdentifier("workspace.exam.detail.section")
                    }
                } else if !model.isLoading && model.error == nil {
                    ContentUnavailableView("Exam unavailable", systemImage: "graduationcap",
                                           description: Text("This exam is no longer in your subscriptions."))
                }
            }
        }
        .navigationTitle("Exam Details")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("workspace.exam.detail")
        .environment(\.timeZone, YoungCalendarDate.shanghai)
        .environment(\.calendar, YoungCalendarDate.calendar)
        .task(id: account.sessionRevision) { await model.load() }
        .refreshable { await model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .serverSubscriptionsDidChange)) { _ in
            Task { await model.load() }
        }
        .overlay { if model.isLoading && model.exam(id: examID) == nil { ProgressView() } }
    }
}

private struct ServerWorkspaceExamTimeView: View {
    let exam: ServerWorkspaceExam

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let date = exam.examDate {
                Text(date, style: .date)
            } else {
                Text("Date unavailable")
            }
            if exam.startTime != nil || exam.endTime != nil {
                Text("\(exam.startTime.map { ServerCatalogDisplay.time(.int($0)) } ?? "—") – \(exam.endTime.map { ServerCatalogDisplay.time(.int($0)) } ?? "—")")
            } else {
                Text("Time unavailable")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}
