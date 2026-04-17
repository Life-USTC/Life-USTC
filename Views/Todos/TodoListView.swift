//
//  TodoListView.swift
//  Life@USTC
//
//  Created on 2026/4/17.
//

import SwiftUI

@Observable
class TodoListViewModel {
    var todos: [ServerTodo] = []
    var isLoading = false
    var error: String?

    func load() async {
        isLoading = true
        error = nil
        do {
            let response: ServerTodoListResponse =
                try await ServerClient.shared.request(.listTodos)
            todos = response.todos.sorted {
                if $0.completed != $1.completed {
                    return !$0.completed
                }
                if let d0 = $0.dueAt, let d1 = $1.dueAt {
                    return d0 < d1
                }
                return $0.createdAt > $1.createdAt
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func toggleCompletion(_ todo: ServerTodo) async {
        do {
            let _: SuccessResponse = try await ServerClient.shared.request(
                .updateTodo(
                    id: todo.id,
                    UpdateTodoRequest(
                        title: nil, content: nil, priority: nil,
                        dueAt: nil, completed: !todo.completed
                    )
                )
            )
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete(_ todo: ServerTodo) async {
        do {
            try await ServerClient.shared.requestVoid(.deleteTodo(id: todo.id))
            todos.removeAll { $0.id == todo.id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct TodoListView: View {
    @State private var viewModel = TodoListViewModel()
    @State private var showingCreate = false

    var body: some View {
        List {
            if !ServerClient.shared.isAuthenticated {
                Section {
                    ContentUnavailableView(
                        "Sign In Required",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("Sign in to the server to use Todos.")
                    )
                }
            } else if viewModel.todos.isEmpty && !viewModel.isLoading {
                Section {
                    ContentUnavailableView(
                        "No Todos",
                        systemImage: "checklist",
                        description: Text("Tap + to create your first todo.")
                    )
                }
            } else {
                let pending = viewModel.todos.filter { !$0.completed }
                let completed = viewModel.todos.filter { $0.completed }

                if !pending.isEmpty {
                    Section("Pending") {
                        ForEach(pending) { todo in
                            TodoRow(todo: todo, viewModel: viewModel)
                        }
                    }
                }

                if !completed.isEmpty {
                    Section("Completed") {
                        ForEach(completed) { todo in
                            TodoRow(todo: todo, viewModel: viewModel)
                        }
                    }
                }
            }
        }
        .navigationTitle("Todos")
        .toolbar {
            if ServerClient.shared.isAuthenticated {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreate) {
            TodoEditView { await viewModel.load() }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .overlay {
            if viewModel.isLoading && viewModel.todos.isEmpty {
                ProgressView()
            }
        }
    }
}

private struct TodoRow: View {
    let todo: ServerTodo
    let viewModel: TodoListViewModel

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.toggleCompletion(todo) }
            } label: {
                Image(
                    systemName: todo.completed
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .foregroundStyle(todo.completed ? .green : .secondary)
                .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .font(.body)
                    .strikethrough(todo.completed)
                    .foregroundStyle(
                        todo.completed ? .secondary : .primary
                    )

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
                    .foregroundStyle(
                        dueAt < Date() && !todo.completed ? .red : .secondary
                    )
                }
            }

            Spacer()

            Image(systemName: todo.priority.iconName)
                .font(.caption)
                .foregroundStyle(priorityColor(todo.priority))
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await viewModel.delete(todo) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func priorityColor(_ priority: TodoPriority) -> Color {
        switch priority {
        case .high: .red
        case .medium: .orange
        case .low: .blue
        }
    }
}

#Preview {
    NavigationStack {
        TodoListView()
    }
}
