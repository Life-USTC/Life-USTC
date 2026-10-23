import SwiftUI

struct ServerSectionHomeworksView: View {
    @State private var model: ServerSectionHomeworksModel
    @Bindable private var account = ServerAccountStore.shared
    @State private var showsDeleted = false
    @State private var showingCreate = false
    @State private var editingHomework: ServerHomework?
    @State private var deletingHomework: ServerHomework?

    init(sectionJwId: Int) {
        _model = State(initialValue: ServerSectionHomeworksModel(sectionJwId: sectionJwId))
    }

    private var visibleHomeworks: [ServerHomework] {
        model.homeworks.filter { showsDeleted || !model.isDeleted($0) }
    }

    var body: some View {
        List {
            Section {
                NavigationLink("Homework History") { ServerHomeworkHistoryView(sectionJwId: model.sectionJwId) }
                    .accessibilityIdentifier("section.homeworks.history")
                Toggle("Show deleted homework", isOn: $showsDeleted)
                    .accessibilityIdentifier("section.homeworks.showDeleted")
            }
            if let error = model.loadError {
                Section {
                    Text(error).foregroundStyle(.red)
                    Button("Retry") { Task { await model.load() } }
                        .accessibilityIdentifier("section.homeworks.load.retry")
                }
            }
            if let error = model.deleteError {
                Section {
                    Text(error).foregroundStyle(.red)
                        .accessibilityIdentifier("section.homeworks.delete.error")
                    Button("Retry") { Task { await model.retryDelete() } }
                        .disabled(!model.canRetryDelete)
                        .accessibilityIdentifier("section.homeworks.delete.retry")
                }
            }
            if visibleHomeworks.isEmpty && !model.isLoading && model.loadError == nil {
                ContentUnavailableView("No Homework", systemImage: "doc.text",
                                       description: Text("No shared homework has been published for this section."))
            }
            ForEach(visibleHomeworks) { homework in
                HStack(spacing: 12) {
                    if model.isDeleted(homework) {
                        homeworkLabel(homework)
                    } else {
                        NavigationLink { ServerHomeworkDetailView(homeworkID: homework.id) } label: {
                            homeworkLabel(homework)
                        }
                    }
                    if model.mutatingID == homework.id { ProgressView() }
                    if model.canEdit(homework) {
                        Menu {
                            Button("Edit") { editingHomework = homework }
                            if model.canDelete(homework) {
                                Button("Delete", role: .destructive) { deletingHomework = homework }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Homework actions")
                        .accessibilityIdentifier("section.homeworks.actions.\(homework.id)")
                    }
                }
                .accessibilityIdentifier("section.homeworks.row.\(homework.id)")
            }
            if !account.isAuthenticated {
                Section { NavigationLink("Sign in to add shared homework") { ServerAccountView() } }
            } else if model.viewer?.isSuspended == true {
                Section {
                    Text(model.viewer?.suspensionReason ?? String(localized: "Your account is suspended."))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Shared Homework")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("section.homeworks")
        .environment(\.timeZone, YoungCalendarDate.shanghai)
        .toolbar {
            if model.canCreate {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCreate = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("New Homework")
                        .accessibilityIdentifier("section.homeworks.create")
                }
            }
        }
        .sheet(isPresented: $showingCreate) {
            ServerHomeworkEditorView(sectionJwId: model.sectionJwId)
        }
        .sheet(item: $editingHomework) { homework in
            ServerHomeworkEditorView(sectionJwId: model.sectionJwId, homework: homework)
        }
        .confirmationDialog("Delete this homework?", isPresented: Binding(
            get: { deletingHomework != nil }, set: { if !$0 { deletingHomework = nil } }
        ), titleVisibility: .visible, presenting: deletingHomework) { homework in
            Button("Delete", role: .destructive) {
                deletingHomework = nil
                Task { await model.delete(id: homework.id) }
            }
            Button("Cancel", role: .cancel) { deletingHomework = nil }
        } message: { homework in
            Text(homework.title)
        }
        .task(id: account.sessionRevision) { await model.load() }
        .refreshable { await model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .serverCommunityDidChange)) { _ in
            if model.mutatingID == nil { Task { await model.load() } }
        }
        .onChange(of: account.sessionRevision) { _, _ in
            showingCreate = false
            editingHomework = nil
            deletingHomework = nil
        }
        .overlay { if model.isLoading && model.homeworks.isEmpty { ProgressView() } }
    }

    private func homeworkLabel(_ homework: ServerHomework) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(homework.title).font(.headline)
            if model.isDeleted(homework) {
                Label("Deleted", systemImage: "trash").font(.caption).foregroundStyle(.secondary)
                if let deletedAt = homework.deletedAt { Text(deletedAt, style: .date).font(.caption) }
            } else {
                if let dueAt = homework.submissionDueAt {
                    HStack(spacing: 4) {
                        Text("Deadline")
                        Text(dueAt, style: .date)
                        Text(dueAt, style: .time)
                    }
                    .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Date unavailable").font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    if homework.isMajor { Label("Major assignment", systemImage: "star") }
                    if homework.requiresTeam { Label("Group work", systemImage: "person.2") }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
