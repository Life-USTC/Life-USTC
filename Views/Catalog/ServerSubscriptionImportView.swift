import SwiftUI

struct ServerSubscriptionImportView: View {
    @State private var model = ServerSubscriptionImportModel()
    @Bindable private var account = ServerAccountStore.shared
    @Environment(\.locale) private var locale

    private var accountKey: String {
        "\(ServerClient.shared.baseURL.absoluteString)|\(account.user?.id ?? (account.isAuthenticated ? "signed-in" : "anonymous"))"
    }

    private var apiLocale: String { locale.language.languageCode?.identifier == "en" ? "en-us" : "zh-cn" }
    private var isBusy: Bool { model.isLoading || model.isMatching || model.isImporting }

    var body: some View {
        Form {
            if !account.isAuthenticated {
                Section {
                    Text("Sign in to manage your section subscriptions.")
                    NavigationLink("Server Account") { ServerAccountView() }
                }
            } else {
                inputSection
                if let error = model.error {
                    Section {
                        Text(error).foregroundStyle(.red)
                            .accessibilityIdentifier("subscription_import_error")
                        if model.semesters.isEmpty {
                            Button("Retry") { Task { await model.load() } }
                                .accessibilityIdentifier("subscription_import_load_retry")
                        }
                    }
                }
                if let result = model.result { resultSection(result) }
                if let preview = model.preview { previewSections(preview) }
            }
        }
        .navigationTitle("Import course codes")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: accountKey) { await model.load() }
    }

    private var inputSection: some View {
        Section {
            Picker("Semester", selection: $model.semesterID) {
                Text("Choose a semester").tag(nil as Int?)
                ForEach(model.semesters) { semester in
                    Text(ServerCatalogDisplay.semesterName(semester)).tag(Optional(semester.id))
                }
            }
            .disabled(isBusy)
            .accessibilityIdentifier("subscription_import_semester")
            VStack(alignment: .leading, spacing: 6) {
                Text("Course or teaching-section codes").font(.subheadline)
                TextEditor(text: $model.input)
                    .frame(minHeight: 100)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(isBusy)
                    .accessibilityLabel("Course or teaching-section codes")
                    .accessibilityIdentifier("subscription_import_input")
            }
            if let inputError = model.inputError, !model.isLoading {
                Text(inputError).font(.caption).foregroundStyle(.secondary)
            }
            Button {
                Task { await model.match(locale: apiLocale) }
            } label: {
                HStack {
                    Text("Preview matches")
                    if model.isMatching { ProgressView() }
                }
            }
            .disabled(!model.canMatch)
            .accessibilityIdentifier("subscription_import_preview")
            if model.isLoading { ProgressView() }
            Link("Undergraduate academic system", destination: URL(string: "https://jw.ustc.edu.cn")!)
                .accessibilityIdentifier("subscription_import_undergraduate")
            Link("Graduate academic system", destination: URL(string: "https://yjs1.ustc.edu.cn")!)
                .accessibilityIdentifier("subscription_import_graduate")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Copy course selection results from an academic system, then paste codes such as MATH1001.01 for the matching semester.")
                Text("Subscriptions organize your workspace and do not change official course enrollment.")
            }
        }
    }

    @ViewBuilder
    private func previewSections(_ preview: ServerSubscriptionQueryResponse) -> some View {
        Section("Matched teaching sections") {
            if preview.sections.isEmpty {
                Text("No teaching sections matched. Check the codes and semester.")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("subscription_import_empty")
            }
            ForEach(preview.sections) { section in
                Toggle(isOn: Binding(
                    get: { model.selectedSectionIDs.contains(section.id) },
                    set: { selected in
                        if selected != model.selectedSectionIDs.contains(section.id) { model.toggleSelection(section.id) }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.course.map { ServerCatalogDisplay.name($0.nameCn, $0.nameEn) } ?? section.code)
                            .font(.headline)
                        Text(section.code).font(.caption.monospaced()).foregroundStyle(.secondary)
                        if let semester = section.semester {
                            Text(ServerCatalogDisplay.semesterName(semester)).font(.caption).foregroundStyle(.secondary)
                        }
                        if let teachers = section.teachers, !teachers.isEmpty {
                            Text(teachers.map { ServerCatalogDisplay.name($0.nameCn, $0.nameEn) }.joined(separator: ", "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if let kind = model.subscribedKinds[section.id] {
                            Text("Already subscribed · \(kind.title)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(isBusy || model.subscribedKinds[section.id] != nil || section.retiredAt != nil)
                .accessibilityIdentifier("subscription_import_section_\(section.id)")
            }
            if !preview.sections.isEmpty {
                Text("Selected sections: \(model.selectedSectionIDs.count)")
                    .accessibilityIdentifier("subscription_import_selected_count")
                if model.selectedSectionIDs.count > 500 {
                    Text("Select at most 500 teaching sections.").font(.caption).foregroundStyle(.secondary)
                }
                Button {
                    Task { await model.importSelection(locale: apiLocale) }
                } label: {
                    HStack {
                        Text("Subscribe to selected sections")
                        if model.isImporting { ProgressView() }
                    }
                }
                .disabled(!model.canImport)
                .accessibilityIdentifier("subscription_import_confirm")
            }
        }
        if !preview.unmatchedCodes.isEmpty {
            Section {
                ForEach(preview.unmatchedCodes, id: \.self) { code in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(code).font(.body.monospaced())
                        if let suggestions = preview.suggestions[code], !suggestions.isEmpty {
                            Text("Suggested codes: \(suggestions.joined(separator: ", "))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("subscription_import_unmatched_\(code)")
                }
            } header: {
                Text("Unmatched codes")
            } footer: {
                Text("Suggestions are not selected automatically. Edit the pasted codes and preview again to use them.")
            }
        }
    }

    private func resultSection(_ result: ServerSubscriptionBatchResponse) -> some View {
        Section("Import result") {
            Text("Added sections: \(result.addedCount)")
                .accessibilityIdentifier("subscription_import_added")
            Text("Already subscribed: \(result.unchangedCount)")
            if !result.unmatchedSectionIds.isEmpty {
                Text("Unavailable sections: \(result.unmatchedSectionIds.count)")
                Text("Some selected sections are no longer available. Preview again to check the current matches.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
