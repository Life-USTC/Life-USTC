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
                    if !publication.renderedBodyHtml.isEmpty {
                        ServerRenderedContent(html: publication.renderedBodyHtml)
                            .accessibilityIdentifier("publication.body")
                    } else {
                        Text("The article body is unavailable.").foregroundStyle(.secondary)
                            .accessibilityIdentifier("publication.body.unavailable")
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
                                            .font(.caption).foregroundStyle(Color.primary)
                                    }
                                }
                            }
                        }
                    }
                }
                let attribution = articleInformation(publication.revision)
                if !attribution.isEmpty {
                    Section("Article information") {
                        ForEach(attribution, id: \.label) { item in
                            LabeledContent(LocalizedStringKey(item.label), value: item.value)
                        }
                    }
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
        .toolbar {
            if let publication = model.publication {
                ServerContentShareButton(route: .publication(publication.id))
            }
        }
        .accessibilityIdentifier("publication.detail")
        .environment(\.timeZone, YoungCalendarDate.shanghai)
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    private func articleInformation(_ revision: ServerPublicationRevision) -> [(label: String, value: String)] {
        [("Author", revision.author),
         ("Reporter", revision.reporter == revision.author ? nil : revision.reporter),
         ("Editor", revision.editor), ("Original publisher", revision.originalPublisher),
         ("Category", revision.category)].compactMap { label, value in
            PublicationAttribution.value(value).map { (label: label, value: $0) }
        }
    }

}
