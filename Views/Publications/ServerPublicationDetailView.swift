import SwiftUI

struct ServerPublicationDetailView: View {
    @State private var model: ServerPublicationDetailModel

    init(id: String) { _model = State(initialValue: ServerPublicationDetailModel(id: id)) }

    var body: some View {
        List {
            if let error = model.error {
                Section {
                    Text(error).foregroundStyle(.red)
                    Button("Retry") { Task { await model.load() } }.disabled(model.isLoading)
                        .accessibilityIdentifier("publication.detail.retry")
                }
            }
            if let publication = model.publication {
                Section {
                    Text(publication.revision.title).font(.title2.bold())
                    Text(LocalizedStringKey(publication.publicationType.title)).foregroundStyle(.secondary)
                    NavigationLink(publication.source.name) {
                        ServerPublicationsView(filters: .init(sources: [publication.source.id]))
                    }
                    if let date = publication.revision.publishedAt {
                        LabeledContent("Published") { Text(date, style: .date) }
                    } else {
                        LabeledContent("Published", value: String(localized: "Date unavailable"))
                    }
                    if let date = publication.revision.updatedAtSource {
                        LabeledContent("Updated") { Text(date, style: .date) }
                    }
                    if let url = URL(string: publication.revision.sourcePageUrl ?? publication.canonicalUrl) {
                        Link("Open original", destination: url)
                    }
                }
                if let summary = publication.revision.summary, !summary.isEmpty {
                    Section("Summary") { Text(summary).textSelection(.enabled) }
                }
                Section {
                    if let markdown = publication.revision.bodyMarkdown, !markdown.isEmpty {
                        ServerCommunityMarkdown(content: markdown)
                            .accessibilityIdentifier("publication.body")
                    } else {
                        Text("The article body is unavailable.").foregroundStyle(.secondary)
                            .accessibilityIdentifier("publication.body.unavailable")
                    }
                    ForEach(publication.revision.images ?? []) { image in
                        if let url = URL(string: image.url, relativeTo: ServerClient.shared.baseURL)?.absoluteURL {
                            VStack(alignment: .leading, spacing: 6) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image): image.resizable().scaledToFit()
                                    case .failure: Label("Image unavailable", systemImage: "photo")
                                    default: ProgressView().frame(maxWidth: .infinity)
                                    }
                                }
                                .accessibilityLabel(image.altText ?? image.title ?? String(localized: "Article image"))
                                if let caption = image.caption, !caption.isEmpty {
                                    Text(caption).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                let attachments = (publication.revision.objects ?? []).filter { $0.kind == .asset }
                if !attachments.isEmpty {
                    Section("Attachments") {
                        ForEach(attachments) { object in
                            if let url = URL(string: object.url, relativeTo: ServerClient.shared.baseURL)?.absoluteURL {
                                Link(destination: url) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Label(object.filename ?? object.altText ?? String(localized: "Attachment"), systemImage: "paperclip")
                                        Text(ByteCountFormatter.string(fromByteCount: Int64(object.size), countStyle: .file))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                Section("Article information") {
                    if let author = publication.revision.author { LabeledContent("Author", value: author) }
                    if let reporter = publication.revision.reporter, reporter != publication.revision.author {
                        LabeledContent("Reporter", value: reporter)
                    }
                    if let editor = publication.revision.editor { LabeledContent("Editor", value: editor) }
                    if let publisher = publication.revision.originalPublisher { LabeledContent("Original publisher", value: publisher) }
                    if let category = publication.revision.category { LabeledContent("Category", value: category) }
                }
                if !publication.alsoPublishedIn.isEmpty {
                    Section("Also published in") {
                        ForEach(publication.alsoPublishedIn) { sibling in
                            NavigationLink(sibling.source.name) { ServerPublicationDetailView(id: sibling.id) }
                        }
                    }
                }
            }
            if model.isLoading { ProgressView().frame(maxWidth: .infinity) }
        }
        .navigationTitle("Publication")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("publication.detail")
        .environment(\.timeZone, YoungCalendarDate.shanghai)
        .task { await model.load() }
        .refreshable { await model.load() }
    }
}
