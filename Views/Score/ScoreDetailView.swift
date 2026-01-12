//
//  ScoreView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/12.
//

import SwiftData
import SwiftUI

private enum SortPreference: String, CaseIterable {
    case gpa = "GPA"
    case code = "Course Code"
}

struct ScoreDetailView: View {
    @Query(sort: \ScoreSheet.gpa, order: .forward) private var scoreSheets: [ScoreSheet]

    var scoreSheet: ScoreSheet? {
        scoreSheets.first
    }

    var semesterNameList: [String] {
        scoreSheet?.semesterNameList ?? []
    }

    var semesterGroupedScores: [(name: String, entries: [ScoreEntry])] {
        scoreSheet?
            .staged(
                semesterNameToHide: semesterNameToRemove,
                sortPreference: sortPreference?.rawValue
            ) ?? []
    }

    @State var semesterNameToRemove: [String] = []
    @State private var sortPreference: SortPreference? = .gpa

    @State private var showShareSheet = false
    @State private var exportedImage: UIImage?

    var semesterButton: some View {
        Menu {
            ForEach(semesterNameList, id: \.self) { semester in
                Button {
                    if semesterNameToRemove.contains(semester) {
                        semesterNameToRemove.removeAll(where: { $0 == semester }
                        )
                    } else {
                        semesterNameToRemove.append(semester)
                    }
                } label: {
                    HStack {
                        if !(semesterNameToRemove.contains(semester)) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                        Text(semester)
                    }
                }
                .menuActionDismissBehavior(.disabled)
            }
        } label: {
            Label(
                "Choose Semester",
                systemImage: "square.dashed.inset.filled"
            )
            .lineLimit(1)
        }
    }

    var sortButton: some View {
        Menu {
            ForEach(SortPreference.allCases, id: \.self) { _sortPreference in
                Button {
                    if sortPreference == _sortPreference {
                        sortPreference = nil
                    } else {
                        sortPreference = _sortPreference
                    }
                } label: {
                    HStack {
                        if sortPreference == _sortPreference {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                        Text(_sortPreference.rawValue.localized)
                    }
                }
                .menuActionDismissBehavior(.disabled)
            }
        } label: {
            if sortPreference == nil {
                Label("Sort by: Default", systemImage: "number.square")
                    .hStackLeading()
            } else {
                Label(
                    "Sort by: \(sortPreference!.rawValue.localized)",
                    systemImage: "number.square"
                )
            }
        }
    }

    var rankingView: some View {
        Section {
            VStack(alignment: .leading) {
                HStack {
                    Text(scoreSheet?.majorName ?? "")
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Spacer()

                    if let sheet = scoreSheet {
                        Text("\("Ranking:".localized) \(sheet.majorRank) / \(sheet.majorStdCount)")
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
                if let sheet = scoreSheet {
                    Text("GPA: \(String(format: "%.2f", sheet.gpa))")
                        .font(.title2)
                        .bold()
                }
            }
        } header: {
            HStack(alignment: .bottom) {
                Spacer()
                HStack {
                    semesterButton
                    sortButton
                }
            }
        }
    }

    func makeView(with entries: [ScoreEntry]) -> some View {
        ForEach(entries, id: \.lessonCode) { entry in
            ScoreEntryView(
                entry: entry,
                color: ((entry.gpa ?? 0.0) >= 1.0
                    ? (entry.gpa! >= (scoreSheet?.gpa ?? 0.0)
                        ? .cyan.opacity(0.6) : .orange.opacity(0.6))
                    : .red.opacity(0.6))
            )
        }
    }

    var scoreListView: some View {
        ForEach(
            semesterGroupedScores,
            id: \.name
        ) { semester in
            Section {
                makeView(with: semester.entries)
            } header: {
                Text(semester.name)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
            }
        }
    }

    var listContent: some View {
        Group {
            if scoreSheet != nil {
                rankingView
            }

            if (scoreSheet?.entries ?? []).isEmpty {
                ContentUnavailableView(
                    "No Score Data",
                    systemImage: "chart.bar.doc.horizontal",
                    description: Text("Your scores will appear here once available")
                )
            } else {
                scoreListView
            }
        }
    }

    @MainActor
    func generateLongScreenshot() -> UIImage? {
        let renderer = ImageRenderer(content: listContent.padding(20).background(Color.white))
        renderer.scale = 3.0
        renderer.isOpaque = true
        return renderer.uiImage
    }

    var body: some View {
        List {
            listContent
        }
        .refreshable {
            Task {
                try await ScoreSheet.update()
            }
        }
        .navigationTitle("Score")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    if let image = generateLongScreenshot() {
                        exportedImage = image
                        showShareSheet = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(scoreSheet == nil || (scoreSheet?.entries ?? []).isEmpty)

                Button {
                    Task {
                        try await ScoreSheet.update()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = exportedImage {
                ShareSheet(items: [image])
            }
        }
        .task {
            Task {
                try await ScoreSheet.update()
            }
        }
    }
}
