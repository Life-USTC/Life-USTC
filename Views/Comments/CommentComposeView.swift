//
//  CommentComposeView.swift
//  Life@USTC
//
//  Created on 2026/4/17.
//

import SwiftUI

struct CommentComposeView: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: CommentListViewModel

    @State private var commentBody = ""
    @State private var isAnonymous = false
    @State private var visibility = "public"
    @State private var isSending = false
    @State private var error: String?

    private let visibilityOptions = [
        ("public", "Public"),
        ("logged_in_only", "Logged-in Only"),
        ("anonymous", "Anonymous"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Write a comment…", text: $commentBody, axis: .vertical)
                        .lineLimit(3...10)
                }

                Section {
                    Picker("Visibility", selection: $visibility) {
                        ForEach(visibilityOptions, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }

                    Toggle("Post Anonymously", isOn: $isAnonymous)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task { await send() }
                    }
                    .disabled(
                        commentBody.trimmingCharacters(in: .whitespaces).isEmpty
                            || isSending
                    )
                }
            }
        }
    }

    private func send() async {
        isSending = true
        error = nil

        let request = CreateCommentRequest(
            targetType: viewModel.targetType,
            targetId: viewModel.targetId,
            sectionId: viewModel.sectionId,
            teacherId: viewModel.teacherId,
            body: commentBody.trimmingCharacters(in: .whitespaces),
            visibility: visibility,
            isAnonymous: isAnonymous,
            parentId: nil
        )

        do {
            let _: IDResponse = try await ServerClient.shared.request(
                .createComment(request)
            )
            await viewModel.load()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSending = false
    }
}
