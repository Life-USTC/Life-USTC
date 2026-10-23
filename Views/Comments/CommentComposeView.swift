//
//  CommentComposeView.swift
//  Life@USTC
//
//  Created on 2026/4/17.
//

import SwiftUI

struct CommentComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var account = ServerAccountStore.shared

    let viewModel: CommentListViewModel
    let parentId: String?
    let editingComment: ServerComment?

    init(
        viewModel: CommentListViewModel,
        parentId: String? = nil,
        editingComment: ServerComment? = nil
    ) {
        self.viewModel = viewModel
        self.parentId = parentId
        self.editingComment = editingComment
        _commentBody = State(initialValue: editingComment?.body ?? "")
        _isAnonymous = State(initialValue: editingComment?.isAnonymous ?? false)
        _visibility = State(initialValue: editingComment?.visibility ?? "public")
        _editorRevision = State(initialValue: viewModel.sessionRevision)
        _attachments = State(initialValue: ServerCommentAttachmentsModel(existing: editingComment?.attachments ?? []))
    }

    @State private var commentBody = ""
    @State private var isAnonymous = false
    @State private var visibility = "public"
    @State private var isSending = false
    @State private var error: String?
    @State private var editorRevision: UUID
    @State private var attachments: ServerCommentAttachmentsModel

    private var isCurrentSession: Bool {
        account.isAuthenticated && editorRevision == viewModel.sessionRevision
    }

    private let visibilityOptions = [
        ("public", "Public"),
        ("logged_in_only", "Logged-in Only"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                if isCurrentSession {
                    Section {
                        TextField("Write a comment…", text: $commentBody, axis: .vertical)
                            .lineLimit(3...10)
                            .accessibilityIdentifier("comment_body")
                        if commentBody.utf16.count > 8_000 {
                            Text("Comments must be at most 8,000 characters.")
                                .font(.caption).foregroundStyle(.red)
                        }
                    }

                    Section {
                        Picker("Visibility", selection: $visibility) {
                            ForEach(visibilityOptions, id: \.0) { value, label in
                                Text(LocalizedStringKey(label)).tag(value)
                            }
                        }

                        Toggle("Post Anonymously", isOn: $isAnonymous)
                    }

                    ServerCommentAttachmentsView(model: attachments, isSending: isSending)

                    if !viewModel.canContribute {
                        Section {
                            Text(viewModel.viewer?.suspensionReason ?? "Comment action unavailable".localized)
                                .foregroundStyle(.secondary)
                            Button("Refresh permissions") { Task { await viewModel.load() } }
                                .disabled(viewModel.isLoading || isSending)
                            YoungReauthorizeButton()
                        }
                    }

                    if let error {
                        Section {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                } else {
                    Section { Text("Your account changed. Reopen the editor to continue.") }
                }
            }
            .disabled(isSending)
            .navigationTitle(
                Text(
                    (editingComment != nil
                        ? "Edit Comment"
                        : parentId == nil ? "New Comment" : "Reply").localized
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSending)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await send() }
                    } label: {
                        Text((editingComment == nil ? "Post" : "Save").localized)
                    }
                    .disabled(
                        !isCurrentSession || !viewModel.canContribute || !attachments.canSubmit
                            || CommentListViewModel.bodyValidationError(commentBody) != nil || isSending
                    )
                    .accessibilityIdentifier("comment_submit")
                }
            }
            .interactiveDismissDisabled(isSending || attachments.isBusy)
            .task(id: account.sessionRevision) {
                attachments.invalidateIfSessionChanged()
                if isCurrentSession { await attachments.loadQuota() }
            }
        }
    }

    private func send() async {
        guard isCurrentSession, !isSending else { return }
        isSending = true
        error = nil
        defer { isSending = false }

        do {
            let attachmentIDs = try attachments.uploadIDsForSubmission()
            if let editingComment {
                try await viewModel.updateComment(
                    editingComment,
                    body: commentBody,
                    visibility: visibility,
                    isAnonymous: isAnonymous,
                    attachmentIds: attachmentIDs,
                    expectedRevision: editorRevision
                )
            } else {
                try await viewModel.createComment(
                    body: commentBody, visibility: visibility, isAnonymous: isAnonymous,
                    parentId: parentId, attachmentIds: attachmentIDs, expectedRevision: editorRevision
                )
            }
            dismiss()
        } catch is CancellationError {
            return
        } catch {
            guard isCurrentSession else { return }
            self.error = error.localizedDescription
            viewModel.mutationError = error.localizedDescription
        }
    }
}
