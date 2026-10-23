import QuickLook
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct ServerCommentAttachmentsView: View {
    @Bindable var model: ServerCommentAttachmentsModel
    var isSending = false
    @State private var choosingFile = false

    var body: some View {
        Section {
            ForEach(model.existing) { attachment in
                attachmentRow(filename: attachment.filename, size: attachment.size) {
                    model.removeExisting(attachment.id)
                }
            }
            ForEach(model.drafts) { draft in
                VStack(alignment: .leading, spacing: 6) {
                    attachmentRow(filename: draft.upload.filename, size: draft.upload.size) {
                        model.removeDraft(draft.id)
                    }
                    if draft.upload.isUploading {
                        ProgressView("Uploading attachment…")
                    } else if draft.upload.completion != nil {
                        Label("Ready to attach", systemImage: "checkmark.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if let error = draft.error {
                        Text(error).font(.caption).foregroundStyle(.red)
                        Button("Retry Upload") { Task { await model.retry(draft.id) } }
                            .disabled(isSending || model.isBusy)
                            .accessibilityIdentifier("comment_attachment_retry")
                    }
                }
            }
            if model.isCurrentSession {
                Button { choosingFile = true } label: {
                    Label("Add Attachment", systemImage: "paperclip")
                }
                .disabled(isSending || !model.canAdd)
                .accessibilityIdentifier("comment_add_attachment")
                if model.isBusy && !model.drafts.contains(where: { $0.upload.isUploading }) {
                    ProgressView("Preparing attachment…")
                }
                if model.isLoadingQuota { ProgressView("Loading storage…") }
                if let quota = model.quota { ServerUploadQuotaView(quota: quota) }
                if let error = model.error {
                    Text(error).font(.caption).foregroundStyle(.red)
                    if model.quota == nil {
                        Button("Retry") { Task { await model.loadQuota() } }
                            .accessibilityIdentifier("comment_attachment_quota_retry")
                    }
                }
            } else {
                Text("Your account changed. Close this draft and try again.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Attachments")
        } footer: {
            Text("Only completed uploads are attached when you post. Removing an attachment here keeps the file in Comment Files.")
        }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { Task { await model.importFile(url) } }
            case .failure(let error): model.reportImportError(error)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverSessionDidChange)) { _ in
            model.invalidateIfSessionChanged()
            if !model.isCurrentSession { choosingFile = false }
        }
    }

    private func attachmentRow(filename: String, size: Int, remove: @escaping () -> Void) -> some View {
        HStack(alignment: .top) {
            Image(systemName: "doc").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(filename)
                Text(serverUploadSizeText(size)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(role: .destructive, action: remove) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text(String(format: "Remove attachment %@".localized, filename)))
            .disabled(isSending || model.isBusy)
        }
    }
}

@MainActor
struct ServerCommentAttachmentList: View {
    let attachments: [ServerCommentAttachment]
    @Bindable private var account = ServerAccountStore.shared
    @State private var preview = ServerAttachmentPreviewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(attachments) { attachment in
                Button {
                    Task { await preview.download(attachment) }
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "paperclip")
                        VStack(alignment: .leading, spacing: 3) {
                            Text(attachment.filename)
                            Text(serverUploadSizeText(attachment.size))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if preview.loadingID == attachment.id { ProgressView() }
                    }
                }
                .buttonStyle(.borderless)
                .disabled(!account.isAuthenticated || preview.loadingID != nil)
                .accessibilityIdentifier("comment_attachment_preview_\(attachment.id)")
            }
            if !account.isAuthenticated {
                NavigationLink("Sign in to download attachments") { ServerAccountView() }
            }
            if let error = preview.error {
                Text(error).font(.caption).foregroundStyle(.red)
                Button("Retry") { Task { await preview.retry() } }
                    .accessibilityIdentifier("comment_attachment_preview_retry")
            }
        }
        .quickLookPreview(Binding(get: { preview.url }, set: { if $0 == nil { preview.dismiss() } }))
        .onReceive(NotificationCenter.default.publisher(for: .serverSessionDidChange)) { _ in
            preview.dismiss()
        }
        .onDisappear { preview.dismiss() }
    }
}

@MainActor @Observable
final class ServerAttachmentPreviewModel {
    private let client: ServerClient
    private var revision: UUID?
    private var artifact: ServerDownloadedUpload?
    private var loading: String?
    private var failure: String?
    private var failedAttachment: ServerCommentAttachment?
    private var generation = 0

    init(client: ServerClient = .shared) { self.client = client }

    private var ownsState: Bool { revision == client.sessionRevision && client.isAuthenticated }
    var url: URL? { ownsState ? artifact?.localURL : nil }
    var loadingID: String? { ownsState ? loading : nil }
    var error: String? { ownsState ? failure : nil }

    func download(_ attachment: ServerCommentAttachment) async {
        dismiss()
        revision = client.sessionRevision
        let expectedRevision = client.sessionRevision
        let currentGeneration = generation
        loading = attachment.id
        defer { if generation == currentGeneration { loading = nil } }
        do {
            let downloaded = try await client.downloadUpload(id: attachment.uploadId, filename: attachment.filename,
                                                            expectedRevision: expectedRevision)
            guard generation == currentGeneration, expectedRevision == client.sessionRevision, !Task.isCancelled else {
                downloaded.remove()
                return
            }
            artifact = downloaded
        } catch is CancellationError {
            return
        } catch {
            guard generation == currentGeneration, expectedRevision == client.sessionRevision, !Task.isCancelled else { return }
            failure = error.localizedDescription
            failedAttachment = attachment
        }
    }

    func retry() async {
        guard ownsState, let failedAttachment else { return }
        await download(failedAttachment)
    }

    func dismiss() {
        generation += 1
        artifact?.remove()
        artifact = nil
        loading = nil
        failure = nil
        failedAttachment = nil
    }
}
