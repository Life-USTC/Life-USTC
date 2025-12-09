//
//  ScoreView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/12.
//

import SwiftData
import SwiftUI

private struct ScoreView: View {
    var ScoreEntry: ScoreEntry
    var color: Color

    var cornerRadius: CGFloat = {
        guard #available(iOS 26, *) else {
            return 5
        }
        return 10
    }()

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(ScoreEntry.courseName)
                    .fontWeight(.bold)
                HStack {
                    Text(String(ScoreEntry.credit))
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    Text(ScoreEntry.courseCode)
                        .foregroundColor(.gray)
                }
                .font(.subheadline)
            }

            Spacer()

            Group {
                if ScoreEntry.gpa == nil {
                    if ScoreEntry.score.isEmpty {
                        Image(systemName: "xmark")
                            .frame(width: 85, height: 30)
                            .background(
                                Stripes(
                                    config: .init(
                                        background: .gray,
                                        foreground: .white.opacity(0.4)
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                            )
                    } else {
                        Text("\(String(ScoreEntry.score))")
                            .frame(width: 85, height: 30)
                            .background(
                                Stripes(
                                    config: .init(
                                        background: .cyan,
                                        foreground: .white.opacity(0.4)
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                            )
                    }
                } else {
                    HStack(alignment: .center, spacing: 0) {
                        Text("\(ScoreEntry.score)")
                            .frame(width: 35)
                            .padding(.horizontal, 4)
                        Divider()
                        Text("\(String(ScoreEntry.gpa!))")
                            .frame(width: 35)
                            .padding(.horizontal, 4)
                    }
                    .frame(width: 85, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(color)
                    )
                }
            }
            .font(.body)
            .fontWeight(.bold)
            .foregroundColor(.white)
        }
    }
}

private enum SortPreference: String, CaseIterable {
    case gpa = "GPA"
    case code = "Course Code"
}

struct ScoreDetailView: View {
    @Query(sort: \Score.gpa, order: .forward) var summaries: [Score]

    @State var semesterNameToRemove: [String] = []
    @State private var sortPreference: SortPreference? = .gpa

    var rankingView: some View {
        Section {
            VStack(alignment: .leading) {
                HStack {
                    Text(summaries.first?.majorName ?? "")
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Spacer()

                    if let s = summaries.first {
                        Text("\("Ranking:".localized) \(s.majorRank) / \(s.majorStdCount)")
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
                if let s = summaries.first {
                    Text("GPA: \(String(format: "%.2f", s.gpa))")
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

    func makeView(with courses: [ScoreEntry]) -> some View {
        ForEach(courses, id: \.lessonCode) { course in
            ScoreView(
                ScoreEntry: course,
                color: ((course.gpa ?? 0.0) >= 1.0
                    ? (course.gpa! >= (summaries.first?.gpa ?? 0.0)
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
        .refreshable {
            Task {
                try await Score.update()
            }
        }
        .navigationTitle("Score")
        .task {
            Task {
                try await Score.update()
            }
        }
    }
}

extension ScoreDetailView {
    private var filteredCourses: [ScoreEntry] {
        let courses = summaries.first?.entries ?? []
        return courses.filter { course in
            !semesterNameToRemove.contains(course.semesterName)
        }
    }

    private var sortedCourses: [ScoreEntry] {
        filteredCourses.sorted { lhs, rhs in
            guard let preference = sortPreference else { return true }

            switch preference {
            case .gpa:
                return (lhs.gpa ?? 0) > (rhs.gpa ?? 0)
            case .code:
                return lhs.lessonCode < rhs.lessonCode
            }
        }
    }

    var sortedScore: [(name: String, courses: [ScoreEntry])] {
        // Group courses by semester
        let groupedBySemester = sortedCourses.categorise { course in
            course.semesterName
        }

        // Sort semesters by semester ID (descending)
        return
            groupedBySemester
            .sorted { lhs, rhs in
                lhs.value[0].semesterID > rhs.value[0].semesterID
            }
            .map { ($0.key, $0.value) }
    }

    var semesterNameList: [String] {
        let courses = summaries.first?.entries ?? []
        return
            courses
            .categorise { $0.semesterName }
            .sorted(by: { lhs, rhs in lhs.value[0].semesterID > rhs.value[0].semesterID })
            .map { $0.key }
    }
}

extension ScoreDetailView {
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
