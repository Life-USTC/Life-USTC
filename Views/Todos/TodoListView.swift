//
//  TodoListView.swift
//  Life@USTC
//
//  Created on 2026/4/17.
//

import SwiftUI

struct TodoListView: View {
    @State private var model = ServerTodoListModel()
    @State private var account = ServerAccountStore.shared
    @State private var showingCreate = false
    @State private var showingFilters = false
    @State private var editingTodo: ServerTodo?
    @State private var deletingTodo: ServerTodo?

    private struct LoadKey: Equatable {
        let revision: UUID
        let query: ServerTodoListQuery
    }

    var body: some View {
        List {
            if !account.isAuthenticated {
                ContentUnavailableView(
                    "Sign In Required",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("Sign in to the server to use Todos.")
                )
            } else {
                Section {
                    if let counts = model.counts {
                        HStack {
                            count("Pending", value: counts.incomplete, id: "pending")
                            count("Completed", value: counts.completed, id: "completed")
                            count("Overdue", value: counts.overdue, id: "overdue")
                        }
                    }
                    Picker("Todo Status", selection: $model.query.status) {
                        ForEach(ServerTodoStatus.allCases, id: \.self) { status in
                            Text(LocalizedStringKey(status.title)).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("todo.status")
                }

                if let error = model.loadError {
                    errorSection(error, id: "todo.load") {
                        Task { await model.load() }
                    }
                }
                if let error = model.mutationError {
                    errorSection(error, id: "todo.mutation") {
                        Task { await model.retryMutation() }
                    }
                    .disabled(!model.canRetryMutation)
                }
                if model.showsPreviousFilterResults && !model.isLoading {
                    Text("Showing previous results. Retry to apply filters.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if model.todos.isEmpty && !model.isLoading && model.loadError == nil {
                    ContentUnavailableView(
                        "No Todos", systemImage: "checklist",
                        description: Text("No todos match these filters.")
                    )
                }
                let pending = model.todos.filter { !$0.completed }
                let completed = model.todos.filter(\.completed)
                if !pending.isEmpty {
                    Section("Pending") {
                        ForEach(pending) { todo in row(todo) }
                    }
                }
                if !completed.isEmpty {
                    Section("Completed") {
                        ForEach(completed) { todo in row(todo) }
                    }
                }
            }
        }
        .accessibilityIdentifier("todo.list")
        .navigationTitle("Todos")
        .environment(\.timeZone, YoungCalendarDate.shanghai)
        .toolbar {
            if account.isAuthenticated {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingFilters = true
                    } label: {
                        Label("Filter Todos", systemImage: model.query.hasAdditionalFilters
                              ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityIdentifier("todo.filters")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreate = true
                    } label: {
                        Label("New Todo", systemImage: "plus")
                    }
                    .accessibilityIdentifier("todo.create")
                }
            }
        }
        .sheet(isPresented: $showingCreate) { TodoEditView() }
        .sheet(item: $editingTodo) { TodoEditView(todo: $0) }
        .sheet(isPresented: $showingFilters) { TodoFiltersView(query: $model.query) }
        .confirmationDialog(
            "Delete Todo?",
            isPresented: Binding(get: { deletingTodo != nil }, set: { if !$0 { deletingTodo = nil } }),
            titleVisibility: .visible,
            presenting: deletingTodo
        ) { todo in
            Button("Delete", role: .destructive) {
                Task { await model.delete(todo) }
            }
            .accessibilityIdentifier("todo.delete.confirm")
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This todo will be permanently deleted.")
        }
        .task(id: LoadKey(revision: account.sessionRevision, query: model.query)) {
            await model.load()
        }
        .refreshable { await model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .serverWorkspaceDidChange)) { _ in
            Task { await model.load() }
        }
        .onChange(of: account.sessionRevision) { _, _ in
            showingCreate = false
            showingFilters = false
            editingTodo = nil
            deletingTodo = nil
        }
        .overlay {
            if model.isLoading && model.todos.isEmpty {
                ProgressView().accessibilityIdentifier("todo.loading")
            }
        }
    }

    private func row(_ todo: ServerTodo) -> some View {
        TodoRow(
            todo: todo, isMutating: model.mutatingIDs.contains(todo.id),
            toggle: { Task { await model.toggleCompletion(todo) } },
            edit: { editingTodo = todo },
            delete: { deletingTodo = todo }
        )
    }

    private func count(_ label: String, value: Int, id: String) -> some View {
        VStack(spacing: 4) {
            Text(value.formatted()).font(.title2.monospacedDigit())
            Text(LocalizedStringKey(label)).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("todo.count.\(id)")
    }

    private func errorSection(_ error: String, id: String, retry: @escaping () -> Void) -> some View {
        Section {
            Text(error)
                .font(.callout)
                .foregroundStyle(.red)
                .accessibilityIdentifier("\(id).error")
            Button("Retry", action: retry).accessibilityIdentifier("\(id).retry")
        }
    }
}

private struct TodoRow: View {
    let todo: ServerTodo
    let isMutating: Bool
    let toggle: () -> Void
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                if isMutating {
                    ProgressView()
                } else {
                    Image(systemName: todo.completed ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(todo.completed ? .green : .secondary)
                        .font(.title3)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(LocalizedStringKey(todo.completed ? "Mark as Pending" : "Mark as Completed")))
            .accessibilityIdentifier("todo.complete.\(todo.id)")

            Button(action: edit) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(todo.title)
                        .font(.body)
                        .strikethrough(todo.completed)
                        .foregroundStyle(todo.completed ? .secondary : .primary)
                    if let content = todo.content, !content.isEmpty {
                        Text(content)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    if let dueAt = todo.dueAt {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(dueAt, style: .date)
                            Text(dueAt, style: .time)
                        }
                        .font(.caption2)
                        .foregroundStyle(dueAt < Date() && !todo.completed ? .red : .secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("todo.edit.\(todo.id)")

            Image(systemName: todo.priority.iconName)
                .font(.caption)
                .foregroundStyle(priorityColor)
                .accessibilityLabel(Text(LocalizedStringKey(todo.priority.displayName)))
        }
        .disabled(isMutating)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: delete) {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityIdentifier("todo.delete.\(todo.id)")
            Button(action: edit) { Label("Edit", systemImage: "pencil") }
                .tint(.blue)
        }
    }

    private var priorityColor: Color {
        switch todo.priority {
        case .high: .red
        case .medium: .orange
        case .low: .blue
        }
    }
}

private struct TodoFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding private var query: ServerTodoListQuery
    @State private var draft: ServerTodoListQuery

    init(query: Binding<ServerTodoListQuery>) {
        _query = query
        _draft = State(initialValue: query.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Priority", selection: $draft.priority) {
                        Text("Any Priority").tag(Optional<TodoPriority>.none)
                        ForEach(TodoPriority.allCases, id: \.self) { priority in
                            Text(LocalizedStringKey(priority.displayName)).tag(Optional(priority))
                        }
                    }
                    .accessibilityIdentifier("todo.filter.priority")
                }
                Section {
                    Toggle("Due on or after", isOn: Binding(
                        get: { draft.dueFrom != nil },
                        set: { draft.dueFrom = $0 ? YoungCalendarDate.dayStart(Date()) : nil }
                    ))
                    .accessibilityIdentifier("todo.filter.hasDueFrom")
                    if draft.dueFrom != nil {
                        DatePicker("Due on or after", selection: Binding(
                            get: { draft.dueFrom ?? Date() }, set: { draft.dueFrom = $0 }
                        ), displayedComponents: .date)
                        .accessibilityIdentifier("todo.filter.dueFrom")
                    }
                    Toggle("Due on or before", isOn: Binding(
                        get: { draft.dueThrough != nil },
                        set: { draft.dueThrough = $0 ? draft.dueFrom ?? YoungCalendarDate.dayStart(Date()) : nil }
                    ))
                    .accessibilityIdentifier("todo.filter.hasDueThrough")
                    if draft.dueThrough != nil {
                        DatePicker("Due on or before", selection: Binding(
                            get: { draft.dueThrough ?? Date() }, set: { draft.dueThrough = $0 }
                        ), displayedComponents: .date)
                        .accessibilityIdentifier("todo.filter.dueThrough")
                    }
                } footer: {
                    Text("Dates use Shanghai time.")
                }
                if !draft.isValid {
                    Text("The end date must be on or after the start date.")
                        .foregroundStyle(.red)
                }
                Button("Reset Filters") {
                    draft.priority = nil
                    draft.dueFrom = nil
                    draft.dueThrough = nil
                }
                .accessibilityIdentifier("todo.filter.reset")
            }
            .environment(\.timeZone, YoungCalendarDate.shanghai)
            .environment(\.calendar, YoungCalendarDate.calendar)
            .navigationTitle("Todo Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply Filters") {
                        query = draft
                        dismiss()
                    }
                    .disabled(!draft.isValid)
                    .accessibilityIdentifier("todo.filter.apply")
                }
            }
        }
    }
}

#Preview {
    NavigationStack { TodoListView() }
}
