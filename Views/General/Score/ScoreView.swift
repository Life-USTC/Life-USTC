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

    var rankingView: some View {
        Section {
            VStack(alignment: .leading) {
                HStack {
                    Text(score.majorName)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(
                        "\("Ranking:".localized) \(score.majorRank) / \(score.majorStdCount)"
                    )
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                }
                Text("GPA: " + String(score.gpa))  // Double formatting problem noticed
                    .font(.title2).bold()
            }
        } header: {
            HStack(alignment: .bottom) {
                AsyncStatusLight(status: _score.status)

                Spacer()

                HStack {
                    semesterButton
                    sortButton
                }
            }
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

    var body: some View {
        List {
            rankingView
            scoreListView
        }
        .asyncStatusOverlay(_score.status)
        .listStyle(.grouped)
        .scrollContentBackground(.hidden)
        .refreshable {
            _score.triggerRefresh()
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

    var semesterNameList: [String] {
        score.courses
            .categorise { course in
                course.semesterName
            }
            .sorted(by: { lhs, rhs in
                lhs.value[0].semesterID > rhs.value[0].semesterID
            })
            .map { $0.key }
    }
}

extension ScoreView {
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
}

struct ScoreView_Previews: PreviewProvider {
    static var previews: some View {
        ScoreView()
    }
}
