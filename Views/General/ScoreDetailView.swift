//
//  ScoreView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/12.
//

import SwiftUI

private struct ScoreView: View {
    var courseScore: CourseScore
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
                Text(courseScore.courseName)
                    .fontWeight(.bold)
                HStack {
                    Text(String(courseScore.credit))
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    Text(courseScore.courseCode)
                        .foregroundColor(.gray)
                }
                .font(.subheadline)
            }

            Spacer()

            Group {
                if courseScore.gpa == nil {
                    if courseScore.score.isEmpty {
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
                        Text("\(String(courseScore.score))")
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
                        Text("\(courseScore.score)")
                            .frame(width: 35)
                            .padding(.horizontal, 4)
                        Divider()
                        Text("\(String(courseScore.gpa!))")
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
                Text("GPA: \(String(format: "%.2f", score.gpa))")
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
            ScoreView(
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
        .refreshable {
            _score.triggerRefresh()
        }
        .navigationTitle("Score")
    }
}

extension ScoreDetailView {
    private var filteredCourses: [CourseScore] {
        score.courses.filter { course in
            !semesterNameToRemove.contains(course.semesterName)
        }
    }

    private var sortedCourses: [CourseScore] {
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

    var sortedScore: [(name: String, courses: [CourseScore])] {
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

struct ScoreView_Previews: PreviewProvider {
    static var previews: some View {
        ScoreDetailView()
    }
}
