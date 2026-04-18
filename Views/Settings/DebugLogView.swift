//
//  DebugLogView.swift
//  Life@USTC
//
//  In-app log viewer for production debugging. Shows buffered log entries
//  from AppLogger with color-coded levels and share/clear controls.
//

import SwiftUI

struct DebugLogView: View {
    @State private var entries: [LogEntry] = []
    @State private var filterLevel: LogEntry.LogLevel? = nil
    @State private var searchText = ""

    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    private var filteredEntries: [LogEntry] {
        entries.filter { entry in
            if let level = filterLevel, entry.level != level { return false }
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                return entry.message.lowercased().contains(query)
                    || entry.category.lowercased().contains(query)
            }
            return true
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Level", selection: $filterLevel) {
                    Text("All").tag(Optional<LogEntry.LogLevel>.none)
                    ForEach([LogEntry.LogLevel.debug, .info, .warning, .error], id: \.self) { level in
                        Text(level.rawValue.capitalized).tag(Optional(level))
                    }
                }
                .pickerStyle(.segmented)
            }

            if filteredEntries.isEmpty {
                ContentUnavailableView("No Logs", systemImage: "doc.text", description: Text("No log entries match the current filter."))
            } else {
                Section {
                    ForEach(filteredEntries) { entry in
                        LogEntryRow(entry: entry)
                    }
                } header: {
                    Text("\(filteredEntries.count) entries")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Filter by message or category")
        .navigationTitle("Debug Logs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ShareLink("Export Logs", item: exportText())
                    Button(role: .destructive) {
                        AppLogger.shared.clear()
                        refreshEntries()
                    } label: {
                        Label("Clear Logs", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear { refreshEntries() }
        .onReceive(refreshTimer) { _ in refreshEntries() }
    }

    private func refreshEntries() {
        entries = AppLogger.shared.entries
    }

    private func exportText() -> String {
        filteredEntries.map { entry in
            let ts = Self.dateFormatter.string(from: entry.timestamp)
            return "[\(ts)] [\(entry.level.rawValue.uppercased())] [\(entry.category)] \(entry.message)"
        }.joined(separator: "\n")
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}

// MARK: - Log Entry Row

private struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(levelColor)
                    .frame(width: 8, height: 8)
                Text(entry.category)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
                Spacer()
                Text(entry.timestamp, format: .dateTime.hour().minute().second())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            Text(entry.message)
                .font(.caption)
                .foregroundStyle(levelColor)
                .lineLimit(5)
        }
        .padding(.vertical, 2)
    }

    private var levelColor: Color {
        switch entry.level {
        case .debug: .secondary
        case .info: .primary
        case .warning: .orange
        case .error: .red
        }
    }
}
