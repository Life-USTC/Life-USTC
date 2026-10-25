import SwiftUI

struct ServerPublicationSourcesView: View {
    @State private var model = ServerPublicationSourcesModel()

    var body: some View {
        List {
            if let error = model.error {
                Section {
                    Text(error).foregroundStyle(.red)
                    Button("Retry") { Task { await model.load() } }.disabled(model.isLoading)
                }
            }
            if let directory = model.directory {
                Section {
                    LabeledContent("Sources", value: directory.totals.sourceCount.formatted())
                    LabeledContent("Publications", value: directory.totals.publicationCount.formatted())
                }
                ForEach(directory.groups) { group in
                    Section(LocalizedStringKey(group.knownOrganizationLevel.title)) {
                        ForEach(group.sources) { source in
                            NavigationLink {
                                ServerPublicationsView(filters: .init(sources: [source.id]))
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(source.name).font(.headline)
                                    if !source.hosts.isEmpty {
                                        Text(source.hosts.joined(separator: " · "))
                                            .font(.caption).foregroundStyle(.secondary)
                                            .accessibilityIdentifier("publication.source.hosts.\(source.id)")
                                    }
                                    LabeledContent("Publications", value: source.publicationCount.formatted())
                                        .font(.caption).foregroundStyle(.secondary)
                                    if let lastPublishedAt = source.lastPublishedAt {
                                        Text(lastPublishedAt, style: .date).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .accessibilityIdentifier("publication.source.\(source.id)")
                        }
                    }
                }
                if directory.groups.isEmpty { Text("No publication sources").foregroundStyle(.secondary) }
            }
            if model.isLoading { ProgressView().frame(maxWidth: .infinity) }
        }
        .navigationTitle("Publication Sources")
        .accessibilityIdentifier("publications.sourceDirectory")
        .environment(\.timeZone, YoungCalendarDate.shanghai)
        .task { await model.load() }
        .refreshable { await model.load() }
    }
}
