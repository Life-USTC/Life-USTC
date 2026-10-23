import SwiftUI

@MainActor @Observable
final class ServerRoomMapModel {
    private let client: ServerClient
    private(set) var result: ServerRoomMap?
    private(set) var isLoading = false
    private(set) var error: String?

    init(client: ServerClient = .shared) { self.client = client }

    static func normalizedCode(_ code: String) -> String? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.utf16.count <= 64 else { return nil }
        let normalized = trimmed.precomposedStringWithCompatibilityMapping.uppercased()
        return normalized.range(of: "^[A-Z0-9]+(?:-[A-Z0-9]+)*$", options: .regularExpression) == nil ? nil : normalized
    }

    func lookup(_ code: String) async {
        guard !isLoading else { return }
        result = nil
        error = nil
        guard let code = Self.normalizedCode(code) else {
            error = "Enter a room code of up to 64 letters, numbers, and separating hyphens.".localized
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let value = try await client.fetchRoomMap(code: code)
            guard !Task.isCancelled else { return }
            result = value
        } catch is CancellationError { return }
        catch { self.error = error.localizedDescription }
    }
}

struct ServerRoomMapView: View {
    @State private var code = ""
    @State private var model = ServerRoomMapModel()
    @State private var expanded = false

    var body: some View {
        List {
            Section {
                TextField("Room code", text: $code)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { Task { await model.lookup(code) } }
                    .accessibilityIdentifier("room_code")
                Button("Find Room Map") { Task { await model.lookup(code) } }
                    .disabled(model.isLoading || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("room_lookup")
            }
            Section("Example Rooms") {
                HStack {
                    ForEach(["3A204", "3A205", "2101"], id: \.self) { sample in
                        Button(sample) { code = sample; Task { await model.lookup(sample) } }
                            .buttonStyle(.bordered)
                            .disabled(model.isLoading)
                    }
                }
            }
            if model.isLoading { ProgressView("Loading room map…") }
            if let error = model.error { Section { CampusErrorRow(message: error) { await model.lookup(code) } } }
            if let result = model.result {
                Section(result.code) {
                    if let building = result.building { LabeledContent("Building", value: building) }
                    if let floor = result.floor { LabeledContent("Floor", value: floor) }
                    switch result.status {
                    case .highlighted: Label("Room highlighted", systemImage: "mappin.circle.fill")
                    case .overview: Text("This map shows the building or floor only. It does not confirm this room exists.").foregroundStyle(.secondary)
                    case .unavailable: ContentUnavailableView("Map unavailable", systemImage: "map", description: Text("No map is available for this room code."))
                    }
                    if let rawURL = result.imageUrl, let url = URL(string: rawURL, relativeTo: ServerClient.shared.baseURL)?.absoluteURL {
                        CampusRoomMapImage(url: url)
                            .frame(minHeight: 220)
                        Button { expanded = true } label: { Label("Expand Map", systemImage: "arrow.up.left.and.arrow.down.right") }
                            .sheet(isPresented: $expanded) { CampusRoomMapZoomView(url: url, title: result.code) }
                    }
                    if let rawURL = result.sourceImageUrl, let url = URL(string: rawURL, relativeTo: ServerClient.shared.baseURL)?.absoluteURL {
                        Link("Original Map", destination: url)
                    }
                }
            } else if !model.isLoading && model.error == nil {
                ContentUnavailableView("Find a Classroom", systemImage: "map", description: Text("Enter a room code or choose an example to see its map."))
            }
        }
        .navigationTitle("Room Maps")
    }
}

private struct CampusRoomMapImage: View {
    let url: URL
    @State private var reload = 0

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFit()
            case .failure:
                VStack {
                    Text("Unable to load map image.").foregroundStyle(.secondary)
                    Button("Retry") { reload += 1 }
                }
            default: ProgressView()
            }
        }
        .id(reload)
    }
}

private struct CampusRoomMapZoomView: View {
    let url: URL
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var previousScale: CGFloat = 1

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    CampusRoomMapImage(url: url)
                        .frame(width: geometry.size.width * scale, height: geometry.size.height * scale)
                }
                .simultaneousGesture(MagnifyGesture()
                    .onChanged { scale = min(5, max(1, previousScale * $0.magnification)) }
                    .onEnded { _ in previousScale = scale })
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { scale = max(1, scale - 1); previousScale = scale } label: { Image(systemName: "minus.magnifyingglass") }
                        .accessibilityLabel("Zoom Out")
                    Button { scale = min(5, scale + 1); previousScale = scale } label: { Image(systemName: "plus.magnifyingglass") }
                        .accessibilityLabel("Zoom In")
                }
            }
        }
    }
}
