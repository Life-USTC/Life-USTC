//
//  ScoreView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/12.
//

import ScreenshotPreventingSwiftUI
import SwiftUI

private enum SortPreference: String, CaseIterable {
    case gpa = "GPA"
    case code = "Course Code"
}

struct SingleScoreView: View {
    var courseScore: CourseScore
    var gpa: Double

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
            HStack(alignment: .bottom) {
                if courseScore.gpa == nil {
                    Text("\(String(courseScore.score))")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(4)
                        .frame(width: 85, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.accentColor.opacity(0.7))
                        )
                } else {
                    HStack(alignment: .center, spacing: 5) {
                        Text("\(courseScore.score)")
                            .frame(width: 30)
                        Divider()
                        Text("\(String(courseScore.gpa!))")
                            .frame(width: 35)
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 85, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill({ () -> Color in
                                if courseScore.gpa! >= 1.0 {
                                    return courseScore.gpa! >= gpa ? Color.accentColor.opacity(0.7) : Color.orange.opacity(0.7)
                                } else {
                                    return Color.red.opacity(0.6)
                                }
                            }())
                    )
                }
            }
        }
    }
}

struct ScoreView: View {
    @AppStorage("scoreViewSemesterNameToRemove") var semesterNameToRemove: [String] = []
    @AppStorage("scoreViewSortPreference") private var sortPreference: SortPreference?
    @AppStorage("scoreViewPreventScreenShot") var preventScreenShot: Bool = false
    @StateObject var scoreDelegate = ScoreDelegate.shared
    var score: Score {
        scoreDelegate.data
    }

    var status: AsyncViewStatus {
        scoreDelegate.status
    }

    @State var showSettings: Bool = false

    var sortedScore: [(name: String, courses: [CourseScore])] {
        var result = score.courseScores
        for name in semesterNameToRemove {
            result.removeAll(where: { $0.semesterName == name })
        }
        result.sort(by: { $0.semesterID < $1.semesterID })

        switch sortPreference {
        case .none:
            break
        case let .some(wrapped):
            switch wrapped {
            case .gpa:
                result.sort(by: { ($0.gpa ?? 0) > ($1.gpa ?? 0) })
            case .code:
                result.sort(by: { $0.lessonCode < $1.lessonCode })
            }
        }

        // map to dictionary
        return Dictionary(grouping: result, by: { $0.semesterName })
            .sorted(by: { $0.value[0].semesterID > $1.value[0].semesterID })
            .map { ($0.key, $0.value) }
    }

    var semesterList: [String] {
        Array(Set(score.courseScores.map(\.semesterName)))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading) {
                // Title
                VStack(alignment: .leading) {
                    HStack {
                        Text(score.majorName)
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("Rating:".localized + String(score.majorRank) + "/" + String(score.majorStdCount))
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)
                    }
                    Text("GPA: " + String(score.gpa)) // Double formatting problem noticed
                        .font(.title2)
                        .bold()
                }
                .padding(.vertical, 5)

                // Score:
                ForEach(sortedScore, id: \.name) {
                    Text($0.name)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    ForEach($0.courses) { course in
                        Divider()
                        SingleScoreView(courseScore: course, gpa: score.gpa)
                            .padding(.vertical, 5)
                    }
                    Divider()
                        .padding(.bottom, 45)
                }
            }
        }
        .refreshable {
            scoreDelegate.userTriggerRefresh()
        }
        .screenshotProtected(isProtected: preventScreenShot)
        .sheet(isPresented: $showSettings) { sheet }
        .padding([.leading, .trailing])
        .asyncViewStatusMask(status: status)
        .toolbar {
            Button {
                showSettings.toggle()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .navigationTitle("Score")
        .navigationBarTitleDisplayMode(.inline)
    }

    var sheet: some View {
        NavigationStack {
            List {
                Menu {
                    ForEach(semesterList, id: \.self) { semester in
                        Button {
                            if semesterNameToRemove.contains(semester) {
                                semesterNameToRemove.removeAll(where: { $0 == semester })
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
                    Label("Semester: \(String(semesterList.filter { !semesterNameToRemove.contains($0) }.map { $0.prefix(6) }.joined(separator: ",")))",
                          systemImage: "square.dashed.inset.filled")
                        .lineLimit(1)
                        .hStackLeading()
                }

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
                        Label("Sort by: \(sortPreference!.rawValue.localized)", systemImage: "number.square")
                            .hStackLeading()
                    }
                }
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
