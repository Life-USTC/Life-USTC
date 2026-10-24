import SwiftUI

enum ServerCalendarLinks {
    static func section(_ jwID: Int, baseURL: URL) -> URL {
        baseURL.appendingPathComponent("api/catalog/sections/\(jwID)/calendar.ics")
    }

    static func sections(_ ids: [Int], baseURL: URL) -> URL? {
        let ids = Set(ids).sorted()
        guard !ids.isEmpty, ids.count <= 50, ids.allSatisfy({ $0 > 0 }) else { return nil }
        var components = URLComponents(url: baseURL.appendingPathComponent("api/catalog/sections/calendar.ics"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [.init(name: "sectionIds", value: ids.map(String.init).joined(separator: ","))]
        return components.url
    }
}

struct ServerSectionCalendarView: View {
    let sectionJWID: Int

    var body: some View {
        List {
            ServerCalendarLinkSection(url: ServerCalendarLinks.section(sectionJWID, baseURL: ServerClient.shared.baseURL))
        }
        .navigationTitle("Teaching Section Calendar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ServerMultiSectionCalendarView: View {
    let sections: [ServerLearningSubscription]
    @State private var selected = Set<Int>()

    var body: some View {
        List {
            if let url = ServerCalendarLinks.sections(Array(selected), baseURL: ServerClient.shared.baseURL) {
                ServerCalendarLinkSection(url: url)
                    .id(url)
            }
            Section {
                ForEach(sections.filter { $0.retiredAt == nil }) { section in
                    Toggle(isOn: Binding(get: { selected.contains(section.id) }, set: { enabled in
                        if enabled { selected.insert(section.id) } else { selected.remove(section.id) }
                    })) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(section.code).font(.headline)
                            if let course = section.course {
                                Text(ServerCatalogDisplay.name(course.nameCn, course.nameEn)).font(.subheadline)
                            }
                            if let semester = section.semester {
                                Text(ServerCatalogDisplay.semesterName(semester)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(selected.count >= 50 && !selected.contains(section.id))
                    .accessibilityIdentifier("calendar_export_section_\(section.id)")
                }
            } header: {
                Text("Choose up to 50 sections")
            } footer: {
                Text("Combined calendars include active teaching sections. Historical sections can be exported from their detail page.")
            }
            let historical = sections.filter { $0.retiredAt != nil }
            if !historical.isEmpty {
                Section("Historical sections") {
                    ForEach(historical) { section in
                        NavigationLink {
                            ServerSectionDetailView(jwId: section.jwId)
                        } label: {
                            Label(section.code, systemImage: "clock.arrow.circlepath")
                        }
                        .accessibilityIdentifier("calendar_export_historical_\(section.id)")
                    }
                }
            }
        }
        .navigationTitle("Combined Section Calendar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ServerCalendarLinkSection: View {
    let url: URL
    @State private var copied = false

    var body: some View {
        Section {
            ShareLink(item: url) {
                Label("Share calendar link", systemImage: "square.and.arrow.up")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("section_calendar_share")
            Button {
                UIPasteboard.general.url = url
                copied = true
            } label: {
                Label(LocalizedStringKey(copied ? "Copied" : "Copy calendar link"), systemImage: "doc.on.doc")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("section_calendar_copy")
            Link(destination: url) {
                Label("Open calendar file", systemImage: "calendar")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("section_calendar_open")
        } footer: {
            Text("Add this public link to a calendar app to follow the section's published schedule and exams.")
        }
    }
}
