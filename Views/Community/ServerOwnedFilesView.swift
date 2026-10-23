import QuickLook
import SwiftUI

@MainActor
struct ServerOwnedFilesView: View {
    @Bindable private var account = ServerAccountStore.shared
    @State private var model: ServerOwnedFilesModel
    @State private var renaming: ServerUpload?
    @State private var deleting: ServerUpload?
    @State private var downloadRetryID: String?
    @State private var filename = ""
    private let client: ServerClient

    init(client: ServerClient = .shared) {
        self.client = client
        _model = State(initialValue: ServerOwnedFilesModel(client: client))
    }

    var body: some View {
        List {
            if client.isAuthenticated {
                Section {
                    if let quota = model.quota {
                        ServerUploadQuotaView(quota: quota)
                    } else if model.isLoading || model.isRefreshingQuota {
                        ProgressView("Loading storage…")
                    }
                    if let error = model.quotaError {
                        errorRow(error) { await model.refreshQuota() }
                    }
                } footer: {
                    Text("Files attached to comments and completed draft uploads appear here.")
                }

                if let error = model.loadError {
                    Section { errorRow(error) { await model.load() } }
                }
                if let error = model.mutationError {
                    Section {
                        Text(error).font(.caption).foregroundStyle(.red)
                        if model.canRetryMutation {
                            Button("Retry") { Task { await model.retryMutation() } }
                                .accessibilityIdentifier("owned_files_mutation_retry")
                        }
                    }
                }
                if let error = model.downloadError {
                    Section {
                        Text(error).font(.caption).foregroundStyle(.red)
                        if let downloadRetryID {
                            Button("Retry") { Task { await model.download(id: downloadRetryID) } }
                                .accessibilityIdentifier("owned_file_preview_retry")
                        }
                    }
                }

                Section {
                    if model.isLoading && model.uploads.isEmpty {
                        ProgressView("Loading files…")
                    } else if model.uploads.isEmpty && model.loadError == nil {
                        ContentUnavailableView("No Files", systemImage: "doc", description: Text("Add an attachment while writing a comment."))
                    }
                    ForEach(model.uploads) { upload in
                        fileRow(upload)
                    }
                }
            } else {
                ContentUnavailableView("Sign In to View Files", systemImage: "person.crop.circle")
            }
        }
        .navigationTitle("Comment Files")
        .task(id: account.sessionRevision) { await model.load() }
        .refreshable { await model.load() }
        .quickLookPreview(Binding(get: { model.preview?.localURL }, set: { if $0 == nil { model.dismissPreview() } }))
        .alert("Rename File", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Filename", text: $filename)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Save") {
                guard let upload = renaming else { return }
                renaming = nil
                let replacement = filename
                Task { await model.rename(id: upload.id, filename: replacement) }
            }
            .disabled(filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .confirmationDialog("Delete File?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let upload = deleting else { return }
                deleting = nil
                Task { await model.delete(id: upload.id) }
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("Deleting this file also removes its comment attachments.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverSessionDidChange)) { notification in
            guard let changed = notification.object as? ServerClient, changed === client else { return }
            renaming = nil
            deleting = nil
            filename = ""
            downloadRetryID = nil
            model.dismissPreview()
        }
        .onDisappear { model.dismissPreview() }
    }

    private func fileRow(_ upload: ServerUpload) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                downloadRetryID = upload.id
                Task { await model.download(id: upload.id) }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "doc").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(upload.filename).foregroundStyle(.primary)
                        Text("\(serverUploadSizeText(upload.size)) · \(upload.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if model.downloadingID == upload.id { ProgressView() }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(model.downloadingID != nil)
            .accessibilityIdentifier("owned_file_preview_\(upload.id)")
            HStack {
                Button("Rename") { filename = upload.filename; renaming = upload }
                    .accessibilityIdentifier("owned_file_rename_\(upload.id)")
                Spacer()
                if model.mutatingID == upload.id { ProgressView() }
                Button("Delete", role: .destructive) { deleting = upload }
                    .accessibilityIdentifier("owned_file_delete_\(upload.id)")
            }
            .font(.subheadline)
            .buttonStyle(.borderless)
            .disabled(model.mutatingID != nil)
        }
        .padding(.vertical, 4)
    }

    private func errorRow(_ message: String, retry: @escaping () async -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message).font(.caption).foregroundStyle(.red)
            Button("Retry") { Task { await retry() } }
                .accessibilityIdentifier("owned_files_retry")
        }
    }
}

struct ServerUploadQuotaView: View {
    let quota: ServerUploadQuota

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(format: "Storage used: %@ of %@".localized,
                        serverUploadSizeText(quota.usedBytes),
                        serverUploadSizeText(quota.quotaBytes)))
            Text(String(format: "Maximum file size: %@".localized,
                        serverUploadSizeText(quota.maxFileSizeBytes)))
                .font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

func serverUploadSizeText(_ size: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
}
