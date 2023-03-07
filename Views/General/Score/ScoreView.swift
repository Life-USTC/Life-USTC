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
    @State var showSettings: Bool = false
    @AppStorage("scoreViewSemesterNameToRemove") var semesterNameToRemove: [String] = []
    @AppStorage("scoreViewSortPreference") private var sortPreference: SortPreference?

    private func sort(score: Score) -> [String: [CourseScore]] {
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
        var semesterDividedResult: [String: [CourseScore]] = [:]
        for _result in result {
            if semesterDividedResult.keys.contains(_result.semesterName) {
                semesterDividedResult[_result.semesterName]?.append(_result)
            } else {
                semesterDividedResult[_result.semesterName] = [_result]
            }
        }
        return semesterDividedResult
    }

    private func semesterList(_ score: Score) -> [String] {
        var result: [String] = []
        for name in score.courseScores.map(\.semesterName) {
            if !result.contains(name) {
                result.append(name)
            }
        }
        return result
    }

    func makeView(with courseScore: CourseScore, score: Score) -> some View {
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
                                    return courseScore.gpa! >= score.gpa ? Color.accentColor.opacity(0.7) : Color.orange.opacity(0.7)
                                } else {
                                    return Color.red.opacity(0.6)
                                }
                            }())
                    )
                }
            }
        }
    }

    @ViewBuilder func sheet(_ score: Score) -> some View {
        NavigationStack {
            List {
                Menu {
                    ForEach(semesterList(score), id: \.self) { semester in
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
                    Label("Semester: \(String(semesterList(score).filter { !semesterNameToRemove.contains($0) }.map { $0.prefix(6) }.joined(separator: ",")))",
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

    @ViewBuilder func makeView(with score: Score) -> some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack {
                    HStack {
                        TitleAndSubTitle(title: "GPA: " + String(score.gpa),
                                         subTitle: score.majorName + "Rating:".localized + String(score.majorRank) + "/" + String(score.majorStdCount),
                                         style: .reverse)
                            .padding(.vertical, 5)
                    }
                    ForEach(sort(score: score).sorted { $0.key > $1.key }, id: \.key) {
                        Text($0.key)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                        ForEach($0.value) { course in
                            Divider()
                            makeView(with: course, score: score)
                                .padding(.vertical, 5)
                        }
                        Divider()
                            .padding(.bottom, 45)
                    }
                }
            }
            .sheet(isPresented: $showSettings) { sheet(score) }
            .padding([.leading, .trailing])
        }
    }

    var body: some View {
        AsyncView(delegate: ScoreDelegate.shared) { score in
            makeView(with: score)
                .toolbar {
                    Button {
                        showSettings.toggle()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
        }
        .navigationBarTitle("Score", displayMode: .inline)
    }
}

struct ScoreView_Previews: PreviewProvider {
    static var previews: some View {
        ScoreView()
    }
}
