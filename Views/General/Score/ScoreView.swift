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
    @State var showAdvancedSettings: Bool = false
    @State var semesterNameToRemove: [String] = []
    @State private var sortPreference: SortPreference?

    func makeView(with courseScore: CourseScore, score: Score) -> some View {
        HStack {
            TitleAndSubTitle(title: courseScore.courseName, subTitle: courseScore.lessonCode, style: .substring)
            if courseScore.gpa == nil {
                Text("\(courseScore.credit)/ /\(courseScore.score)")
            } else {
                Text("\(courseScore.credit)/\(String(courseScore.gpa!))/\(courseScore.score)")
                    .foregroundColor(courseScore.gpa! >= score.gpa ? .green : .red)
            }
        }
    }

    func sheet(_ score: Score) -> some View {
        let semesterList = {
            var result: [String] = []
            for name in score.courseScores.map({ $0.semesterName }) {
                if !result.contains(name) {
                    result.append(name)
                }
            }
            return result
        }()

        return NavigationStack {
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
                    Label("Filter Semester", systemImage: "square.dashed.inset.filled")
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
                                Text(_sortPreference.rawValue)
                            }
                        }
                    }
                } label: {
                    Label("Sort by: \((sortPreference == nil ? "Default" : sortPreference!.rawValue).localized)", systemImage: "number.square")
                        .hStackLeading()
                }
            }
            .listStyle(.plain)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.fraction(0.2)])
    }

    func makeView(with score: Score) -> some View {
        let scoresFiltered = {
            var result = score.courseScores
            for name in semesterNameToRemove {
                result.removeAll(where: { $0.semesterName == name })
            }

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
            return result
        }()

        return NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    TitleAndSubTitle(title: "GPA: " + String(score.gpa),
                                     subTitle: score.majorName + "Rating:".localized + String(score.majorRank) + "/" + String(score.majorStdCount),
                                     style: .reverse)
                        .padding(.bottom, 10)
                    ForEach(scoresFiltered) {
                        Divider()
                        makeView(with: $0, score: score)
                    }
                }
            }
            .sheet(isPresented: $showAdvancedSettings) { sheet(score) }
            .padding([.leading, .trailing])
        }
    }

    var body: some View {
        AsyncView { score in
            makeView(with: score)
        } loadData: {
            try await UstcUgAASClient.main.getScore()
        } refreshData: {
            try await UstcUgAASClient.main.forceUpdateScoreInfo()
            return try await UstcUgAASClient.main.getScore()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Score")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showAdvancedSettings.toggle()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
    }
}
