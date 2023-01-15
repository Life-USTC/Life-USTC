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
    @State var score: Score = .init()
    @State var status: AsyncViewStatus = .inProgress
    @State var showAdvancedSettings: Bool = false

    var semesterList: [String] {
        var result: [String] = []
        for name in score.courseScores.map({ $0.semesterName }) {
            if !result.contains(name) {
                result.append(name)
            }
        }
        return result
    }

    @State var semesterNameToRemove: [String] = []
    @AppStorage("ScoreInfoSortPreference") private var sortPreference: SortPreference?

    var scoresFiltered: [CourseScore] {
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
    }

    func makeView(with courseScore: CourseScore) -> some View {
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

    var loadedView: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    TitleAndSubTitle(title: "GPA: " + String(score.gpa),
                                     subTitle: score.majorName + "Rating:".localized + String(score.majorRank) + "/" + String(score.majorStdCount),
                                     style: .reverse)
                        .padding(.bottom, 10)
                    ForEach(scoresFiltered) {
                        Divider()
                        makeView(with: $0)
                    }
                }
            }
            .sheet(isPresented: $showAdvancedSettings) {
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
                            Label("Sort by: \((sortPreference == nil ? "" : sortPreference!.rawValue).localized)", systemImage: "number.square")
                                .hStackLeading()
                        }
                    }
                    .listStyle(.plain)
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.fraction(0.2)])
            }
            .padding([.leading, .trailing])
        }
    }

    var body: some View {
        mainView
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Score")
            .onAppear {
                asyncBind($score, status: $status) {
                    try await UstcUgAASClient.main.getScore()
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            try await UstcUgAASClient.main.forceUpdateScoreInfo()
                            asyncBind($score, status: $status) {
                                try await UstcUgAASClient.main.getScore()
                            }
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.2.circlepath")
                    }

                    Button {
                        showAdvancedSettings.toggle()
                    } label: {
                        Label("Settings", systemImage: "square.stack")
                    }
                }
            }
    }

    var mainView: some View {
        Group {
            if status == .inProgress {
                ProgressView()
            } else {
                loadedView
            }
        }
    }
}
