import SwiftUI

struct ServerTodoDetailView: View {
    let todoID: String
    @State private var account = ServerAccountStore.shared
    @State private var model: ServerTodoListModel
    @State private var editingTodo: ServerTodo?
    @State private var showingDelete = false

    init(todoID: String) {
        self.todoID = todoID
        let model = ServerTodoListModel()
        model.query.status = .all
        _model = State(initialValue: model)
    }

    private var todo: ServerTodo? { model.todos.first { $0.id == todoID } }

    var body: some View {
        List {
            if !account.isAuthenticated {
                ContentUnavailableView(
                    "Sign In Required", systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("Sign in to the server to use Todos.")
                )
            } else {
                if let error = model.loadError {
                    Section {
                        Text(error).foregroundStyle(.red)
                            .accessibilityIdentifier("todo.detail.load.error")
                        Button("Retry") { Task { await model.load() } }
                            .accessibilityIdentifier("todo.detail.load.retry")
                    }
                }
                if let error = model.mutationError {
                    Section {
                        Text(error).foregroundStyle(.red)
                            .accessibilityIdentifier("todo.detail.mutation.error")
                        Button("Retry") { Task { await model.retryMutation() } }
                            .disabled(!model.canRetryMutation)
                            .accessibilityIdentifier("todo.detail.mutation.retry")
                    }
                }
                if let todo {
                    Section {
                        Text(todo.title)
                            .font(.title3)
                            .accessibilityIdentifier("todo.detail.title")
                        if let content = todo.content, !content.isEmpty {
                            Text(content).textSelection(.enabled)
                                .accessibilityIdentifier("todo.detail.notes")
                        }
                    }
                    Section {
                        LabeledContent("Todo Status") {
                            Text(LocalizedStringKey(todo.completed ? "Completed" : "Pending"))
                        }
                        LabeledContent("Priority") {
                            Label(LocalizedStringKey(todo.priority.displayName), systemImage: todo.priority.iconName)
                        }
                        if let dueAt = todo.dueAt {
                            LabeledContent("Due") {
                                VStack(alignment: .trailing) {
                                    Text(dueAt, style: .date)
                                    Text(dueAt, style: .time)
                                }
                            }
                        }
                    } footer: {
                        if todo.dueAt != nil { Text("Dates use Shanghai time.") }
                    }
                    Section {
                        Button {
                            Task { await model.toggleCompletion(todo) }
                        } label: {
                            Label(LocalizedStringKey(todo.completed ? "Mark as Pending" : "Mark as Completed"),
                                  systemImage: todo.completed ? "circle" : "checkmark.circle")
                        }
                        .accessibilityIdentifier("todo.detail.complete")
                        Button("Edit Todo") { editingTodo = todo }
                            .accessibilityIdentifier("todo.detail.edit")
                        Button("Delete", role: .destructive) { showingDelete = true }
                            .accessibilityIdentifier("todo.detail.delete")
                    }
                    .disabled(model.mutatingIDs.contains(todo.id))
                } else if !model.isLoading && model.loadError == nil {
                    ContentUnavailableView(
                        "Todo Unavailable", systemImage: "checklist",
                        description: Text("This todo may have been deleted.")
                    )
                    .accessibilityIdentifier("todo.detail.unavailable")
                }
            }
        }
        .navigationTitle("Todo")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.timeZone, YoungCalendarDate.shanghai)
        .sheet(item: $editingTodo) { TodoEditView(todo: $0) }
        .confirmationDialog("Delete Todo?", isPresented: $showingDelete,
                            titleVisibility: .visible, presenting: todo) { todo in
            Button("Delete", role: .destructive) { Task { await model.delete(todo) } }
                .accessibilityIdentifier("todo.delete.confirm")
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This todo will be permanently deleted.")
        }
        .task(id: account.sessionRevision) { await model.load() }
        .refreshable { await model.load() }
        .onReceive(NotificationCenter.default.publisher(for: .serverWorkspaceDidChange)) { _ in
            Task { await model.load() }
        }
        .onChange(of: account.sessionRevision) { _, _ in
            editingTodo = nil
            showingDelete = false
        }
        .overlay {
            if model.isLoading && todo == nil { ProgressView() }
        }
    }
}
