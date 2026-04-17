//
//  TodoEditView.swift
//  Life@USTC
//
//  Created on 2026/4/17.
//

import SwiftUI

struct TodoEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var content = ""
    @State private var priority: TodoPriority = .medium
    @State private var hasDueDate = false
    @State private var dueDate = Date().addingTimeInterval(86400)
    @State private var isSaving = false
    @State private var error: String?

    var onSave: (() async -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Notes", text: $content, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Picker("Priority", selection: $priority) {
                        ForEach(TodoPriority.allCases, id: \.self) { p in
                            Label(p.displayName, systemImage: p.iconName)
                                .tag(p)
                        }
                    }

                    Toggle("Due Date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker(
                            "Due",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Todo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        error = nil

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let request = CreateTodoRequest(
            title: title.trimmingCharacters(in: .whitespaces),
            content: content.isEmpty ? nil : content,
            priority: priority.rawValue,
            dueAt: hasDueDate ? formatter.string(from: dueDate) : nil
        )

        do {
            let _: IDResponse = try await ServerClient.shared.request(
                .createTodo(request)
            )
            await onSave?()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}

#Preview {
    TodoEditView()
}
