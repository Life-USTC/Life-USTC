//
//  TodoEditView.swift
//  Life@USTC
//
//  Created on 2026/4/17.
//

import SwiftUI

struct TodoEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var account = ServerAccountStore.shared
    @State private var model: ServerTodoEditorModel

    init(todo: ServerTodo? = nil) {
        _model = State(initialValue: ServerTodoEditorModel(todo: todo))
    }

    var body: some View {
        NavigationStack {
            Form {
                if model.isCurrentSession {
                    Section {
                        TextField("Todo Title", text: $model.title)
                            .accessibilityIdentifier("todo.title")
                        TextField("Notes", text: $model.content, axis: .vertical)
                            .lineLimit(3...6)
                            .accessibilityIdentifier("todo.notes")
                    }

                    Section {
                        Picker("Priority", selection: $model.priority) {
                            ForEach(TodoPriority.allCases, id: \.self) { priority in
                                Label(LocalizedStringKey(priority.displayName), systemImage: priority.iconName)
                                    .tag(priority)
                            }
                        }
                        .accessibilityIdentifier("todo.priority")
                        Toggle("Due Date", isOn: $model.hasDueDate)
                            .accessibilityIdentifier("todo.hasDueDate")
                        if model.hasDueDate {
                            DatePicker(
                                "Due", selection: $model.dueDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .accessibilityIdentifier("todo.dueDate")
                        }
                    } footer: {
                        Text("Dates use Shanghai time.")
                    }

                    if let validationError = model.validationError,
                       !model.title.isEmpty || !model.content.isEmpty {
                        Text(validationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("todo.validation")
                    }
                    if let error = model.error {
                        Section {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.callout)
                                .accessibilityIdentifier("todo.save.error")
                            Button("Retry") { Task { await save() } }
                                .disabled(!model.canSave)
                                .accessibilityIdentifier("todo.save.retry")
                        }
                    }
                }
            }
            .disabled(model.isSaving)
            .environment(\.timeZone, YoungCalendarDate.shanghai)
            .environment(\.calendar, YoungCalendarDate.calendar)
            .navigationTitle(LocalizedStringKey(model.isEditing ? "Edit Todo" : "New Todo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(model.isSaving)
                        .accessibilityIdentifier("todo.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if model.isSaving { ProgressView() } else { Text("Save") }
                    }
                    .disabled(!model.canSave)
                    .accessibilityIdentifier("todo.save")
                }
            }
        }
        .interactiveDismissDisabled(model.isSaving)
        .onChange(of: account.sessionRevision) { _, _ in dismiss() }
    }

    private func save() async {
        if await model.save() { dismiss() }
    }
}

#Preview {
    TodoEditView()
}
