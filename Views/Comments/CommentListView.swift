//
//  CommentListView.swift
//  Life@USTC
//
//  Created on 2026/4/17.
//

import SwiftUI

struct CommentListView: View {
    @Bindable private var account = ServerAccountStore.shared
    @State var viewModel: CommentListViewModel
    @State private var showingCompose = false
    @State private var replyingTo: ServerComment?
    @State private var editingComment: ServerComment?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.viewer?.isSuspended == true {
                Label(viewModel.viewer?.suspensionReason ?? "Comment action unavailable".localized,
                      systemImage: "person.crop.circle.badge.exclamationmark")
                    .font(.caption).foregroundStyle(.secondary).padding()
            }
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
                if viewModel.hiddenCount > 0 {
                    ContentUnavailableView {
                        Label("No Visible Comments", systemImage: "eye.slash")
                    } description: {
                        Text("Some comments are hidden from your view.")
                    } actions: {
                        if !account.isAuthenticated {
                            NavigationLink("Sign In") { ServerAccountView() }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Comments",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Be the first to comment.")
                    )
                }
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
                            canContribute: viewModel.canContribute,
                            showsThreadLink: viewModel.focusedCommentID == nil,
                            isMutating: { viewModel.mutatingIDs.contains($0) },
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

                }
                .padding(.horizontal)
            }
            if viewModel.hiddenCount > 0 {
                Text(String(format: "%d hidden comments".localized, viewModel.hiddenCount))
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal)
            }
        }
        .toolbar {
            if viewModel.canContribute {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCompose = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New Comment")
                    .accessibilityIdentifier("comment_compose")
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
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
        .task(id: account.sessionRevision) { await viewModel.load() }
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
    let canContribute: Bool
    let showsThreadLink: Bool
    let isMutating: (String) -> Bool
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
                if comment.isAncestryPlaceholder == true {
                    Label("Hidden comment", systemImage: "eye.slash")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else if comment.isAnonymous || comment.authorHidden == true {
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
                    if let identifier = author.username ?? author.id {
                        NavigationLink {
                            ServerPublicUserProfileView(identifier: identifier)
                        } label: {
                            Text(author.name ?? author.username ?? "User".localized)
                                .font(.subheadline.bold())
                        }
                    } else {
                        Text(author.name ?? "User".localized).font(.subheadline.bold())
                    }
                }

                Spacer()

                if canContribute && (comment.canEdit == true || comment.canDelete == true) {
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
                    .disabled(isMutating(comment.id))
                }

                if showsThreadLink && comment.isAncestryPlaceholder != true {
                    NavigationLink {
                        ServerCommentThreadView(commentID: comment.id)
                    } label: {
                        Text(comment.createdAt, style: .relative)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("View comment thread")
                } else {
                    Text(comment.createdAt, style: .relative)
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            if comment.isAncestryPlaceholder != true {
                if let html = comment.renderedBody, !html.isEmpty {
                    ServerRenderedContent(html: html)
                } else {
                    Text(comment.body).textSelection(.enabled)
                }
            }

            if let attachments = comment.attachments, !attachments.isEmpty {
                ServerCommentAttachmentList(attachments: attachments)
            }

            if !comment.reactions.isEmpty {
                ScrollView(.horizontal) {
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
                        .disabled(!canContribute || comment.canReact != true || isMutating(comment.id))
                    }
                }
                }
            }

            HStack(spacing: 16) {
            if comment.canReact == true, canContribute {
                Menu {
                    ForEach(["upvote", "downvote", "heart", "laugh", "hooray", "confused", "rocket", "eyes"], id: \.self) { type in
                        Button(reactionEmoji(type)) {
                            let reaction = comment.reactions.first { $0.type == type }
                                ?? ServerCommentReaction(type: type, count: 0, viewerHasReacted: false)
                            onReaction(comment.id, reaction)
                        }
                    }
                } label: { Label("React", systemImage: "face.smiling") }
                .font(.caption)
                .disabled(isMutating(comment.id))
            }
            if comment.canReply == true, canContribute {
                Button("Reply") {
                    onReply(comment)
                }
                .font(.caption)
                .buttonStyle(.borderless)
                .disabled(isMutating(comment.id))
            }
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
                            canContribute: canContribute,
                            showsThreadLink: showsThreadLink,
                            isMutating: isMutating,
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
                .padding(.leading, depth < 3 ? 12 : 0)
            }
        }
        .padding(.vertical, 8)
        .id(comment.id)
        .accessibilityIdentifier("comment_\(comment.id)")
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

struct ServerCommentThreadView: View {
    let commentID: String
    @State private var model: CommentListViewModel

    init(commentID: String) {
        self.commentID = commentID
        _model = State(initialValue: CommentListViewModel(targetType: "", focusedCommentID: commentID))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView { CommentListView(viewModel: model) }
                .onChange(of: model.isLoading) { _, loading in
                    if !loading { proxy.scrollTo(commentID, anchor: .center) }
                }
        }
        .navigationTitle("Comment thread")
        .navigationBarTitleDisplayMode(.inline)
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
