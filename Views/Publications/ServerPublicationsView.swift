import SwiftUI

struct ServerPublicationsView: View {
    @State private var model: ServerPublicationsModel
    @State private var showingFilters = false

    init(filters: ServerPublicationFilters = .init()) {
        _model = State(initialValue: ServerPublicationsModel(filters: filters))
    }

    var body: some View {
        List {
            Section {
                Picker("Publication type", selection: $model.filters.type) {
                    Text("All").tag(nil as ServerPublicationType?)
                    ForEach(ServerPublicationType.allCases, id: \.self) { type in
                        Text(LocalizedStringKey(type.title)).tag(Optional(type))
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("publications.type")
                NavigationLink("Publication Sources") { ServerPublicationSourcesView() }
                    .accessibilityIdentifier("publications.sources")
            }
            if let error = model.error {
                Section {
                    Text(error).foregroundStyle(.red)
                    Button("Retry") { Task { await model.retry() } }
                    .disabled(model.isLoading)
                    .accessibilityIdentifier("publications.retry")
                }
            }
            if model.publications.isEmpty && !model.isLoading && model.error == nil {
                ContentUnavailableView("No publications", systemImage: "newspaper",
                                       description: Text("No news or notices match these filters."))
            }
            ForEach(model.publications) { publication in
                NavigationLink { ServerPublicationDetailView(id: publication.id) } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(publication.revision.title).font(.headline)
                        HStack {
                            Text(publication.source.name)
                            Spacer()
                            Text(LocalizedStringKey(publication.publicationType.title))
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        if let publishedAt = publication.revision.publishedAt {
                            Text(publishedAt, style: .date).font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("Date unavailable").font(.caption).foregroundStyle(.secondary)
                        }
                        if let summary = publication.revision.summary, !summary.isEmpty {
                            Text(summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                        }
                        if let group = publication.foldGroup {
                            Text(String(format: NSLocalizedString("%d other sources", comment: ""), group.siblingCount))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityIdentifier("publication.row.\(publication.id)")
            }
            if model.hasMore {
                Button("Load More") { Task { await model.loadMore() } }
                    .disabled(model.isLoading)
                    .accessibilityIdentifier("publications.more")
            }
            if model.isLoading { ProgressView().frame(maxWidth: .infinity) }
        }
        .navigationTitle("News and Notices")
        .accessibilityIdentifier("publications.list")
        .environment(\.timeZone, YoungCalendarDate.shanghai)
        .searchable(text: $model.filters.query, prompt: "Search publications")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingFilters = true } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
                    .accessibilityLabel("Publication filters")
                    .accessibilityIdentifier("publications.filters")
            }
        }
        .sheet(isPresented: $showingFilters) {
            ServerPublicationFiltersView(filters: model.filters) { model.filters = $0 }
        }
        .task(id: model.filters) { await model.load() }
        .refreshable { await model.load() }
    }
}

private struct ServerPublicationFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ServerPublicationFilters
    @State private var sources = ServerPublicationSourcesModel()
    private let apply: (ServerPublicationFilters) -> Void

    init(filters: ServerPublicationFilters, apply: @escaping (ServerPublicationFilters) -> Void) {
        _draft = State(initialValue: filters)
        self.apply = apply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Group reprints", isOn: $draft.fold)
                        .accessibilityIdentifier("publications.fold")
                } footer: {
                    Text("Combine copies with the same title and publication date.")
                }
                Section("Source organization levels") {
                    ForEach(ServerPublicationOrganizationLevel.allCases, id: \.self) { level in
                        Toggle(LocalizedStringKey(level.title), isOn: Binding(
                            get: { draft.organizationLevels.contains(level) },
                            set: { selected in
                                if selected { draft.organizationLevels.append(level) }
                                else { draft.organizationLevels.removeAll { $0 == level } }
                            }
                        ))
                    }
                }
                Section {
                    LabeledContent("Selected sources", value: "\(draft.sources.count)/20")
                    if let error = sources.error {
                        Text(error).foregroundStyle(.red)
                        Button("Retry") { Task { await sources.load() } }.disabled(sources.isLoading)
                    }
                    ForEach(sources.directory?.groups ?? []) { group in
                        ForEach(group.sources) { source in
                            Toggle(source.name, isOn: Binding(
                                get: { draft.sources.contains(source.id) },
                                set: { selected in
                                    if selected { draft.sources.append(source.id) }
                                    else { draft.sources.removeAll { $0 == source.id } }
                                }
                            ))
                            .disabled(draft.sources.count >= 20 && !draft.sources.contains(source.id))
                        }
                    }
                    if sources.isLoading { ProgressView() }
                } header: {
                    Text("Sources")
                } footer: {
                    Text("Select up to 20 publication sources. Sources and organization levels are combined.")
                }
                Button("Clear filters") {
                    draft.sources = []
                    draft.organizationLevels = []
                    draft.fold = false
                }
            }
            .navigationTitle("Publication filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { apply(draft); dismiss() }
                        .accessibilityIdentifier("publications.filters.apply")
                }
            }
        }
        .task { await sources.load() }
    }
}
