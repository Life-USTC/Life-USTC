import SwiftUI

struct ServerDescriptionView: View {
    @State private var model: ServerDescriptionModel
    @Bindable private var account = ServerAccountStore.shared

    init(target: ServerDescriptionTarget) {
        _model = State(initialValue: ServerDescriptionModel(target: target))
    }

    var body: some View {
        List {
            if let error = model.loadError {
                Section {
                    Text(error).foregroundStyle(.red)
                    Button("Retry") { Task { await model.load() } }
                        .accessibilityIdentifier("description.load.retry")
                }
            }
            if let description = model.description {
                Section("Description") {
                    if description.content.isEmpty {
                        Text("No description.").foregroundStyle(.secondary)
                    } else {
                        ServerCommunityMarkdown(content: description.content)
                            .accessibilityIdentifier("description.content")
                    }
                    if let editedAt = description.lastEditedAt {
                        LabeledContent("Updated") { Text(editedAt, style: .date) }
                    }
                    if let editor = description.lastEditedBy { ServerCommunityActorLink(actor: editor) }
                }
                if !account.isAuthenticated {
                    Section { NavigationLink("Sign in to edit descriptions") { ServerAccountView() } }
                } else if model.viewer?.isSuspended == true {
                    Section {
                        Text(model.viewer?.suspensionReason ?? String(localized: "Your account is suspended."))
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    if model.history.isEmpty { Text("No edit history.").foregroundStyle(.secondary) }
                    ForEach(model.history) { edit in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(edit.createdAt, style: .date)
                                Text(edit.createdAt, style: .time)
                            }
                            .font(.caption).foregroundStyle(.secondary)
                            if let editor = edit.editor { ServerCommunityActorLink(actor: editor) }
                            else { Text("Unknown author").foregroundStyle(.secondary) }
                        }
                        .accessibilityIdentifier("description.history.\(edit.id)")
                        DisclosureGroup("View changes") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Previous description").font(.caption.bold())
                                ServerCommunityMarkdown(content: edit.previousContent ?? "")
                                Text("Updated description").font(.caption.bold())
                                ServerCommunityMarkdown(content: edit.nextContent)
                            }
                        }
                    }
                } header: {
                    Text("Edit History")
                } footer: {
                    Text("History includes up to 20 recent changes.")
                }
            }
        }
        .navigationTitle("Description")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("description.detail")
        .environment(\.timeZone, YoungCalendarDate.shanghai)
        .toolbar {
            if model.canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { model.beginEditing() }
                        .accessibilityIdentifier("description.edit")
                }
            }
        }
        .sheet(isPresented: Binding(get: { model.isEditing }, set: { if !$0 { model.cancelEditing() } })) {
            ServerDescriptionEditorView(model: model)
        }
        .task(id: account.sessionRevision) { await model.load() }
        .refreshable { await model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .serverCommunityDidChange)) { _ in
            if !model.isSaving { Task { await model.load() } }
        }
        .overlay { if model.isLoading && model.description == nil { ProgressView() } }
    }
}

private struct ServerDescriptionEditorView: View {
    @Bindable var model: ServerDescriptionModel

    var body: some View {
        NavigationStack {
            Form {
                if model.isEditing {
                    Section("Description") {
                        TextEditor(text: $model.draft)
                            .frame(minHeight: 220)
                            .accessibilityIdentifier("description.draft")
                    }
                    .disabled(model.isSaving)
                    if let error = model.validationError { Text(error).foregroundStyle(.red) }
                    if let error = model.loadError {
                        Section {
                            Text(error).foregroundStyle(.red)
                            Button("Retry") { Task { await model.load() } }
                        }
                    }
                    if let error = model.saveError {
                        Section {
                            Text(error).foregroundStyle(.red)
                                .accessibilityIdentifier("description.save.error")
                            Button("Retry") { Task { await model.save() } }
                                .disabled(!model.canSave)
                                .accessibilityIdentifier("description.save.retry")
                        }
                    }
                }
            }
            .navigationTitle("Edit Description")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { model.cancelEditing() }.disabled(model.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await model.save() } } label: {
                        if model.isSaving { ProgressView() } else { Text("Save") }
                    }
                    .disabled(!model.canSave)
                    .accessibilityIdentifier("description.save")
                }
            }
        }
        .interactiveDismissDisabled(model.isSaving)
    }
}

struct ServerCommunityMarkdown: View {
    let content: String

    var body: some View {
        if content.isEmpty {
            Text("Empty description").foregroundStyle(.secondary)
        } else {
            Text((try? AttributedString(markdown: content,
                                       options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                 ?? AttributedString(content))
                .textSelection(.enabled)
        }
    }
}

struct ServerCommunityActorLink: View {
    let actor: ServerHomeworkCreator

    var body: some View {
        NavigationLink {
            ServerPublicUserProfileView(identifier: actor.username ?? actor.id)
        } label: {
            Label(actor.name ?? actor.username ?? String(localized: "Community member"), systemImage: "person.crop.circle")
        }
    }
}
