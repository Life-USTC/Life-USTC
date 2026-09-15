//
//  CommentListView.swift
//  Life@USTC
//
//  Created on 2026/4/17.
//

import SwiftUI

@Observable
class CommentListViewModel {
    let targetType: String
    let targetId: String?
    let youngId: String?
    let sectionId: Int?
    let teacherId: Int?

    var comments: [ServerComment] = []
    var hiddenCount = 0
    var isLoading = false
    var error: String?
    var mutationError: String?
    var loadingReplyIDs: Set<String> = []
    var replyErrors: [String: String] = [:]

    init(
        targetType: String,
        targetId: String? = nil,
        youngId: String? = nil,
        sectionId: Int? = nil,
        teacherId: Int? = nil
    ) {
        self.targetType = targetType
        self.targetId = targetId
        self.youngId = youngId
        self.sectionId = sectionId
        self.teacherId = teacherId
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            let response = try await ServerClient.shared.fetchComments(
                targetType: targetType,
                targetId: targetId,
                youngId: youngId,
                sectionId: sectionId,
                teacherId: teacherId
            )
            comments = response.comments
            hiddenCount = response.hiddenCount
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func toggleReaction(commentId: String, reaction: ServerCommentReaction) async {
        guard ServerClient.shared.isAuthenticated else { return }
        mutationError = nil
        do {
            if reaction.hasReacted {
                try await ServerClient.shared.requestVoid(
                    .removeCommentReaction(id: commentId, type: reaction.type)
                )
            } else {
                let _: SuccessResponse = try await ServerClient.shared.request(
                    .addCommentReaction(
                        id: commentId,
                        CommentReactionRequest(type: reaction.type)
                    )
                )
            }
            await load()
        } catch {
            self.mutationError = error.localizedDescription
        }
    }

    func updateComment(
        _ comment: ServerComment,
        body: String,
        visibility: String,
        isAnonymous: Bool
    ) async throws {
        guard ServerClient.shared.isAuthenticated else {
            let error = ServerError.notAuthenticated
            mutationError = error.localizedDescription
            throw error
        }

        mutationError = nil
        do {
            let _: ServerCommentUpdateResponse = try await ServerClient.shared.request(
                .updateComment(
                    id: comment.id,
                    UpdateCommentRequest(
                        body: body,
                        visibility: visibility,
                        isAnonymous: isAnonymous
                    )
                )
            )
            await load()
        } catch {
            mutationError = error.localizedDescription
            throw error
        }
    }

    func deleteComment(_ comment: ServerComment) async {
        guard ServerClient.shared.isAuthenticated else {
            mutationError = ServerError.notAuthenticated.localizedDescription
            return
        }

        mutationError = nil
        do {
            try await ServerClient.shared.requestVoid(.deleteComment(id: comment.id))
            await load()
        } catch {
            mutationError = error.localizedDescription
        }
    }

    func loadMoreReplies(for comment: ServerComment) async {
        guard let cursor = comment.repliesNextCursor,
            !loadingReplyIDs.contains(comment.id)
        else { return }

        loadingReplyIDs.insert(comment.id)
        replyErrors[comment.id] = nil
        defer { loadingReplyIDs.remove(comment.id) }

        do {
            let response = try await ServerClient.shared.fetchCommentReplies(
                id: comment.id,
                cursor: cursor,
                pageSize: 20
            )
            guard mergeReplyPage(response) else {
                throw ServerError.serverError(
                    "Reply thread was not returned by the server".localized
                )
            }
            replyErrors[comment.id] = nil
        } catch {
            guard !Task.isCancelled else { return }
            replyErrors[comment.id] = error.localizedDescription
        }
    }

    private func mergeReplyPage(_ response: ServerCommentRepliesResponse) -> Bool {
        guard let incomingRoot = response.thread.first(where: { $0.id == response.rootId }) else {
            return false
        }

        var mergedRoot = false
        func merge(_ node: ServerComment) -> ServerComment {
            if node.id == response.rootId {
                mergedRoot = true
                var replies = node.replies ?? []
                for incoming in incomingRoot.replies ?? [] {
                    if let index = replies.firstIndex(where: { $0.id == incoming.id }) {
                        replies[index] = mergeExistingReply(replies[index], incoming)
                    } else {
                        replies.append(incoming)
                    }
                }
                return incomingRoot.replacingReplies(replies, nextCursor: response.nextCursor)
            }

            guard let children = node.replies else { return node }
            let updatedChildren = children.map(merge)
            return node.replacingReplies(updatedChildren, nextCursor: node.repliesNextCursor)
        }

        comments = comments.map(merge)
        if mergedRoot {
            replyErrors[response.rootId] = nil
        }
        return mergedRoot
    }

    private func mergeExistingReply(
        _ existing: ServerComment,
        _ incoming: ServerComment
    ) -> ServerComment {
        var replies = existing.replies ?? []
        for incomingReply in incoming.replies ?? [] {
            if let index = replies.firstIndex(where: { $0.id == incomingReply.id }) {
                replies[index] = mergeExistingReply(replies[index], incomingReply)
            } else {
                replies.append(incomingReply)
            }
        }
        return incoming.replacingReplies(
            replies,
            nextCursor: incoming.repliesNextCursor ?? existing.repliesNextCursor
        )
    }
}

struct CommentListView: View {
    @Bindable private var account = ServerAccountStore.shared
    @State var viewModel: CommentListViewModel
    @State private var showingCompose = false
    @State private var replyingTo: ServerComment?
    @State private var editingComment: ServerComment?

    var body: some View {
        Group {
            if let error = viewModel.error, viewModel.comments.isEmpty && !viewModel.isLoading {
                ContentUnavailableView {
                    Label("Unable to Load Comments", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await viewModel.load() } }
                    YoungReauthorizeButton()
                }
            } else if viewModel.comments.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No Comments",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Be the first to comment.")
                )
            } else {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if let error = viewModel.error {
                        CommentErrorBanner(
                            title: "Unable to refresh comments",
                            message: error,
                            retry: { Task { await viewModel.load() } }
                        )
                    }

                    if let error = viewModel.mutationError {
                        CommentErrorBanner(
                            title: "Comment action failed",
                            message: error,
                            dismiss: { viewModel.mutationError = nil }
                        )
                    }

                    ForEach(viewModel.comments) { comment in
                        CommentNodeView(
                            comment: comment,
                            depth: 0,
                            onReaction: { commentId, reaction in
                                Task {
                                    await viewModel.toggleReaction(
                                        commentId: commentId,
                                        reaction: reaction
                                    )
                                }
                            },
                            onReply: { replyingTo = $0 },
                            onEdit: { editingComment = $0 },
                            onDelete: { comment in
                                Task { await viewModel.deleteComment(comment) }
                            },
                            onLoadMoreReplies: { comment in
                                Task { await viewModel.loadMoreReplies(for: comment) }
                            },
                            isLoadingReplies: { viewModel.loadingReplyIDs.contains($0) },
                            replyError: { viewModel.replyErrors[$0] }
                        )
                    }

                    if viewModel.hiddenCount > 0 {
                        Text(String(format: "%d hidden comments".localized, viewModel.hiddenCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            }
        }
        .toolbar {
            if account.isAuthenticated {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCompose = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCompose) {
            CommentComposeView(viewModel: viewModel)
        }
        .sheet(item: $replyingTo) { comment in
            CommentComposeView(viewModel: viewModel, parentId: comment.id)
        }
        .sheet(item: $editingComment) { comment in
            CommentComposeView(viewModel: viewModel, editingComment: comment)
        }
        .task(id: account.isAuthenticated) { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .overlay {
            if viewModel.isLoading && viewModel.comments.isEmpty {
                ProgressView()
            }
        }
    }
}

private struct CommentErrorBanner: View {
    let title: String
    let message: String
    let retry: (() -> Void)?
    let dismiss: (() -> Void)?

    init(
        title: String,
        message: String,
        retry: (() -> Void)? = nil,
        dismiss: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retry = retry
        self.dismiss = dismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                Text(title.localized)
                    .font(.subheadline.bold())
                Spacer()
                if let dismiss {
                    Button("Dismiss", action: dismiss)
                        .font(.caption)
                }
            }
            Text(message)
                .font(.caption)
            if let retry {
                Button("Retry", action: retry)
                    .font(.caption)
            }
        }
        .foregroundStyle(.red)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct CommentNodeView: View {
    let comment: ServerComment
    let depth: Int
    let onReaction: (String, ServerCommentReaction) -> Void
    let onReply: (ServerComment) -> Void
    let onEdit: (ServerComment) -> Void
    let onDelete: (ServerComment) -> Void
    let onLoadMoreReplies: (ServerComment) -> Void
    let isLoadingReplies: (String) -> Bool
    let replyError: (String) -> String?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if comment.isAnonymous {
                    Image(systemName: "person.fill.questionmark")
                        .foregroundStyle(.secondary)
                    Text("Anonymous")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let author = comment.author {
                    if let imageURL = author.image,
                        let url = URL(string: imageURL)
                    {
                        AsyncImage(url: url) { image in
                            image.resizable()
                        } placeholder: {
                            Circle().fill(.quaternary)
                        }
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                    }
                    Text(author.name ?? author.username ?? "User")
                        .font(.subheadline.bold())
                }

                Spacer()

                if comment.canEdit == true || comment.canDelete == true {
                    Menu {
                        if comment.canEdit == true {
                            Button {
                                onEdit(comment)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                        if comment.canDelete == true {
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Comment actions")
                }

                Text(comment.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(comment.body)
                .font(.body)

            if let attachments = comment.attachments, !attachments.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(attachments) { attachment in
                        if let url = URL(string: attachment.url) {
                            Link(destination: url) {
                                Label(attachment.filename, systemImage: "paperclip")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }

            if !comment.reactions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(comment.reactions, id: \.type) { reaction in
                        Button { onReaction(comment.id, reaction) } label: {
                            HStack(spacing: 2) {
                                Text(reactionEmoji(reaction.type))
                                Text("\(reaction.count)")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                reaction.hasReacted
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.secondary.opacity(0.1)
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!ServerClient.shared.isAuthenticated || comment.canReact == false)
                    }
                }
            }

            if comment.canReply != false, ServerClient.shared.isAuthenticated {
                Button("Reply") {
                    onReply(comment)
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }

            if comment.repliesNextCursor != nil {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        onLoadMoreReplies(comment)
                    } label: {
                        if isLoadingReplies(comment.id) {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Load more replies", systemImage: "arrow.down.circle")
                        }
                    }
                    .font(.caption)
                    .disabled(isLoadingReplies(comment.id))

                    if let error = replyError(comment.id) {
                        HStack(spacing: 6) {
                            Text("Unable to load replies")
                            Button("Retry") {
                                onLoadMoreReplies(comment)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }

            if let children = comment.children, !children.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(children) { child in
                        CommentNodeView(
                            comment: child,
                            depth: depth + 1,
                            onReaction: onReaction,
                            onReply: onReply,
                            onEdit: onEdit,
                            onDelete: onDelete,
                            onLoadMoreReplies: onLoadMoreReplies,
                            isLoadingReplies: isLoadingReplies,
                            replyError: replyError
                        )
                    }
                }
                .padding(.leading, 16)
            }
        }
        .padding(.vertical, 8)
        .padding(.leading, CGFloat(depth) * 16)
        .confirmationDialog(
            "Delete this comment?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete(comment)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func reactionEmoji(_ type: String) -> String {
        switch type {
        case "upvote": "👍"
        case "downvote": "👎"
        case "heart": "❤️"
        case "laugh": "😄"
        case "hooray": "🎉"
        case "confused": "😕"
        case "rocket": "🚀"
        case "eyes": "👀"
        default: "•"
        }
    }
}

#Preview {
    NavigationStack {
            CommentListView(
                viewModel: CommentListViewModel(
                    targetType: "section", targetId: "1"
                )
        )
    }
}
