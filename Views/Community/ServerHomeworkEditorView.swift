import SwiftUI

struct ServerHomeworkEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var account = ServerAccountStore.shared
    @State private var model: ServerHomeworkEditorModel
    private let onSaved: ((ServerHomework) -> Void)?

    init(sectionJwId: Int, homework: ServerHomework? = nil, onSaved: ((ServerHomework) -> Void)? = nil) {
        _model = State(initialValue: ServerHomeworkEditorModel(sectionJwId: sectionJwId, homework: homework))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                if model.isCurrentSession {
                    Section {
                        TextField("Homework title", text: $model.title)
                            .accessibilityIdentifier("homework.editor.title")
                        TextField("Description", text: $model.description, axis: .vertical)
                            .lineLimit(4...10)
                            .accessibilityIdentifier("homework.editor.description")
                    }
                    .disabled(!model.canEdit || model.isSaving)
                    Section {
                        DisclosureGroup("Homework writing guide") {
                            Text("Suggested titles: Assignment {N} or {Topic} assignment. Avoid chapter-only titles and omit the course name or code.")
                            Text("Describe the problems first, then the submission method, submission address, and notes. Write Not recorded for unknown problems; omit other unknown details.")
                            Text("These are suggestions and do not prevent saving.")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityIdentifier("homework.editor.guide")
                    }
                    Section {
                        ServerHomeworkDateField(title: "Published", value: $model.publishedAt, identifier: "published")
                        ServerHomeworkDateField(title: "Submission opens", value: $model.submissionStartAt, identifier: "start")
                        ServerHomeworkDateField(title: "Deadline", value: $model.submissionDueAt, identifier: "due")
                    } footer: {
                        Text("Dates use Shanghai time. Turn off a date to clear it.")
                    }
                    .disabled(!model.canEdit || model.isSaving)
                    Section {
                        Toggle("Major assignment", isOn: $model.isMajor)
                            .accessibilityIdentifier("homework.editor.major")
                        Toggle("Group work", isOn: $model.requiresTeam)
                            .accessibilityIdentifier("homework.editor.team")
                    }
                    .disabled(!model.canEdit || model.isSaving)
                    if model.isLoadingPermissions { ProgressView() }
                    if model.viewer?.isSuspended == true {
                        Text(model.viewer?.suspensionReason ?? String(localized: "Your account is suspended."))
                            .foregroundStyle(.secondary)
                    }
                    if let error = model.permissionError {
                        Section {
                            Text(error).foregroundStyle(.red)
                            Button("Retry") { Task { await model.loadPermissions() } }
                                .accessibilityIdentifier("homework.editor.permissions.retry")
                        }
                    }
                    if let error = model.validationError, !model.title.isEmpty || !model.description.isEmpty {
                        Text(error).foregroundStyle(.red)
                            .accessibilityIdentifier("homework.editor.validation")
                    }
                    if let error = model.error {
                        Section {
                            Text(error).foregroundStyle(.red)
                                .accessibilityIdentifier("homework.editor.error")
                            Button("Retry") { Task { await save() } }
                                .disabled(!model.canSave)
                                .accessibilityIdentifier("homework.editor.retry")
                        }
                    }
                }
            }
            .environment(\.timeZone, YoungCalendarDate.shanghai)
            .environment(\.calendar, YoungCalendarDate.calendar)
            .navigationTitle(LocalizedStringKey(model.isEditing ? "Edit Homework" : "New Homework"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(model.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await save() } } label: {
                        if model.isSaving { ProgressView() } else { Text("Save") }
                    }
                    .disabled(!model.canSave)
                    .accessibilityIdentifier("homework.editor.save")
                }
            }
        }
        .interactiveDismissDisabled(model.isSaving)
        .task { await model.loadPermissions() }
        .onChange(of: account.sessionRevision) { _, _ in dismiss() }
    }

    private func save() async {
        guard await model.save(), let homework = model.savedHomework else { return }
        onSaved?(homework)
        dismiss()
    }
}

private struct ServerHomeworkDateField: View {
    let title: LocalizedStringKey
    @Binding var value: Date?
    let identifier: String

    var body: some View {
        Toggle(title, isOn: Binding(get: { value != nil }, set: { value = $0 ? value ?? Date() : nil }))
            .accessibilityIdentifier("homework.editor.\(identifier).enabled")
        if value != nil {
            DatePicker(title, selection: Binding(get: { value ?? Date() }, set: { value = $0 }),
                       displayedComponents: [.date, .hourAndMinute])
                .accessibilityIdentifier("homework.editor.\(identifier).date")
        }
    }
}
