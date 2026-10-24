import SwiftUI

struct ServerCampusLinksView: View {
    @Environment(\.locale) private var locale
    @Bindable private var account = ServerAccountStore.shared
    @State private var model = ServerCampusLinksModel()
    @State private var query = ""

    private var filtered: [ServerCampusLink] { model.links.filter { $0.matches(query) } }

    var body: some View {
        List {
            if let error = model.error {
                Section { CampusErrorRow(message: error) { await model.load(locale: campusAPILocale(locale)) } }
            }
            if let error = model.pinError {
                Section {
                    CampusErrorRow(message: error) {
                        if model.canRetryPin { await model.retryPin() }
                        else { await model.loadPins() }
                    }
                }
            }
            if model.isLoading && model.links.isEmpty { ProgressView("Loading campus links…") }
            if !model.pinnedSlugs.isEmpty {
                Section("Pinned Links") {
                    ForEach(model.pinnedSlugs.compactMap { slug in filtered.first { $0.slug == slug } }) { link in linkRow(link) }
                }
            }
            ForEach(["academic", "community", "services", "campus"], id: \.self) { category in
                let links = filtered.filter { $0.category == category }
                if !links.isEmpty {
                    Section {
                        ForEach(links) { link in linkRow(link) }
                    } header: {
                        Text(categoryTitle(category))
                    }
                }
            }
            if !model.isLoading && filtered.isEmpty && model.error == nil {
                ContentUnavailableView.search(text: query)
            }
            if let limit = model.maxPinnedLinks {
                Section {
                    Text(String(format: "Pin up to %@ links. A new pin replaces the oldest when full.".localized, limit.formatted()))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Campus Links")
        .searchable(text: $query, prompt: "Search names, pinyin, or websites")
        .task(id: "\(account.sessionRevision):\(locale.identifier)") { await model.load(locale: campusAPILocale(locale)) }
        .refreshable { await model.load(locale: campusAPILocale(locale)) }
    }

    private func linkRow(_ link: ServerCampusLink) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let url = URL(string: link.url) {
                Link(destination: url) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(link.title).foregroundStyle(.primary)
                        Text(link.description).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier("campus_link_\(link.slug)")
            }
            if model.canPin || model.changingSlug != nil {
                let pinned = model.pinnedSlugs.contains(link.slug)
                Button { Task { await model.setPinned(slug: link.slug, pinned: !pinned) } } label: {
                    if model.changingSlug == link.slug { ProgressView() }
                    else { Image(systemName: pinned ? "pin.fill" : "pin") }
                }
                .buttonStyle(.borderless)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(!model.canPin)
                .accessibilityLabel(Text((pinned ? "Unpin Link" : "Pin Link").localized))
                .accessibilityIdentifier("campus_pin_\(link.slug)")
            }
        }
    }

    private func categoryTitle(_ category: String) -> String {
        switch category {
        case "academic": "Academic".localized
        case "community": "Community".localized
        case "services": "Services".localized
        default: "Campus".localized
        }
    }
}

struct CampusErrorRow: View {
    let message: String
    let retry: () async -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message).font(.caption).foregroundStyle(.red)
            Button("Retry") { Task { await retry() } }
        }
    }
}

func campusAPILocale(_ locale: Locale) -> String { locale.identifier.hasPrefix("en") ? "en-us" : "zh-cn" }

func campusClock(_ date: Date, locale: Locale) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}

func campusName(_ campus: ServerBusCampus, locale: Locale) -> String {
    campusAPILocale(locale) == "en-us" ? campus.nameEn ?? campus.nameCn : campus.nameCn
}
