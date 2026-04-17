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
    let sectionId: Int?
    let teacherId: Int?

    var comments: [ServerComment] = []
    var hiddenCount = 0
    var isLoading = false
    var error: String?

    init(
        targetType: String,
        targetId: String? = nil,
        sectionId: Int? = nil,
        teacherId: Int? = nil
    ) {
        self.targetType = targetType
        self.targetId = targetId
        self.sectionId = sectionId
        self.teacherId = teacherId
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            let response: ServerCommentListResponse =
                try await ServerClient.shared.request(
                    .listComments(
                        targetType: targetType,
                        targetId: targetId,
                        sectionId: sectionId,
                        teacherId: teacherId
                    )
                )
            comments = response.comments
            hiddenCount = response.hiddenCount
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct CommentListView: View {
    @State var viewModel: CommentListViewModel
    @State private var showingCompose = false

    var body: some View {
        Group {
            if viewModel.comments.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No Comments",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Be the first to comment.")
                )
            } else {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(viewModel.comments) { comment in
                        CommentNodeView(comment: comment, depth: 0)
                    }

                    if viewModel.hiddenCount > 0 {
                        Text("\(viewModel.hiddenCount) hidden comment(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            }
        }
        .toolbar {
            if ServerClient.shared.isAuthenticated {
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
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .overlay {
            if viewModel.isLoading && viewModel.comments.isEmpty {
                ProgressView()
            }
        }
    }
}

private struct CommentNodeView: View {
    let comment: ServerComment
    let depth: Int

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

                Text(comment.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(comment.body)
                .font(.body)

            if let reactions = comment.reactions, !reactions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(reactions, id: \.type) { reaction in
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
                }
            }

            if let children = comment.children, !children.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(children) { child in
                        CommentNodeView(comment: child, depth: depth + 1)
                    }
                }
                .padding(.leading, 16)
            }
        }
        .padding(.vertical, 8)
        .padding(.leading, CGFloat(depth) * 16)
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
