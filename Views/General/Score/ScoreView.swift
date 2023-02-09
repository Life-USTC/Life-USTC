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
            VStack(alignment: .leading) {
                Text(courseScore.courseName)
                    .fontWeight(.bold)
                HStack {
                    Text("\(String(courseScore.credit))")
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
            .navigationBarTitle("Settings", displayMode: .inline)
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
                VStack {
                    HStack {
                        TitleAndSubTitle(title: "GPA: " + String(score.gpa),
                                         subTitle: score.majorName + "Rating:".localized + String(score.majorRank) + "/" + String(score.majorStdCount),
                                         style: .reverse)
                            .padding(.vertical, 5)
                    }
                    ForEach(scoresFiltered) {
                        Divider()
                        makeView(with: $0, score: score)
                            .padding(.vertical, 5)
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
        .navigationBarTitle("Score", displayMode: .inline)
        .toolbar {
            Button {
                showAdvancedSettings.toggle()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

struct ScoreView_Previews: PreviewProvider {
    static var previews: some View {
        ScoreView()
    }
}
