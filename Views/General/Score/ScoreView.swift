//
//  ScoreView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/12.
//

import SwiftUI

private enum SortPreference: String, CaseIterable {
    case gpa = "GPA"
    case code = "Course Code"
}

struct ScoreView: View {
    @ManagedData(.score) var score: Score

    @State var semesterNameToRemove: [String] = []
    @State private var sortPreference: SortPreference? = .gpa
    @State var showSettings: Bool = false

    var rankingView: some View {
        Section {
            VStack(alignment: .leading) {
                HStack {
                    Text(score.majorName)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(
                        "\("Rating:".localized) \(score.majorRank) / \(score.majorStdCount)"
                    )
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                }
                Text("GPA: " + String(score.gpa))  // Double formatting problem noticed
                    .font(.title2).bold()
            }
        } header: {
            AsyncStatusLight(status: _score.status)
        }
    }

    func makeView(with courses: [CourseScore]) -> some View {
        ForEach(courses, id: \.lessonCode) { course in
            SingleScoreView(
                courseScore: course,
                color: ((course.gpa ?? 0.0) >= 1.0
                    ? (course.gpa! >= score.gpa
                        ? .cyan.opacity(0.6) : .orange.opacity(0.6))
                    : .red.opacity(0.6))
            )
        }
    }

    var scoreListView: some View {
        ForEach(sortedScore, id: \.name) { semester in
            Section {
                makeView(with: semester.courses)
            } header: {
                Text(semester.name)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
            }
        }
    }

    var settingButton: some View {
        Button {
            showSettings.toggle()
        } label: {
            Label("Settings", systemImage: "gearshape")
        }
    }

    var body: some View {
        List {
            rankingView
            scoreListView
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .asyncStatusOverlay(_score.status, showLight: false)
        .refreshable {
            _score.triggerRefresh()
        }
        .sheet(isPresented: $showSettings) {
            sheet
        }
        .toolbar {
            settingButton
        }
        .navigationTitle("Score")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension ScoreView {
    var sortedScore: [(name: String, courses: [CourseScore])] {
        score.courses
            .filter { course in
                !semesterNameToRemove.contains(course.semesterName)
            }
            .sorted(by: { lhs, rhs in
                switch sortPreference {
                case .none: return true
                case let .some(wrapped):
                    switch wrapped {
                    case .gpa: return (lhs.gpa ?? 0) > (rhs.gpa ?? 0)
                    case .code: return lhs.lessonCode < rhs.lessonCode
                    }
                }
            })
            .categorise { course in
                course.semesterName
            }
            .sorted(by: { lhs, rhs in
                lhs.value[0].semesterID > rhs.value[0].semesterID
            })
            .map { ($0.key, $0.value) }
    }

    var semesterList: [String] {
        Array(Set(score.courses.map(\.semesterName)))
    }

    var selectedSemesterNames: String {
        String(
            semesterList.filter { name in
                !semesterNameToRemove.contains(name)
            }
            .map { $0.truncated(length: 6) }.joined(separator: ", ")
        )
    }
}

extension ScoreView {
    var semesterButton: some View {
        Menu {
            ForEach(semesterList, id: \.self) { semester in
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
            }
        } label: {
            Label(
                "Semester: \(selectedSemesterNames)",
                systemImage: "square.dashed.inset.filled"
            )
            .lineLimit(1).hStackLeading()
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
                .hStackLeading()
            }
        }
    }

    var sheet: some View {
        NavigationStack {
            List {
                semesterButton
                sortButton
            }
            .listStyle(.plain)
            .navigationBarTitle("Settings", displayMode: .inline)
        }
        .presentationDetents([.fraction(0.2)])
    }
}

struct ScoreView_Previews: PreviewProvider {
    static var previews: some View {
        ScoreView()
    }
}
