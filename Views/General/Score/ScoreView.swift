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
    @ManagedData(ManagedDataSource.score) var score: Score!
    @State var status: AsyncStatus?
    @State var semesterNameToRemove: [String] = []
    @State private var sortPreference: SortPreference? = .gpa
    @State var showSettings: Bool = false

    var rankingView: some View {
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
    }

    var scoreListView: some View {
        ForEach(sortedScore, id: \.name) {
            Text($0.name)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
            ForEach($0.courses, id: \.lessonCode) { course in
                Divider()
                SingleScoreView(courseScore: course, color: { () -> Color in
                    if (course.gpa ?? 0.0) >= 1.0 {
                        return course.gpa! >= score.gpa ?
                            .cyan.opacity(0.6) :
                            .orange.opacity(0.6)
                    }
                    return .red.opacity(0.6)
                }())
                    .padding(.vertical, 5)
            }
            Divider()
                .padding(.bottom, 45)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading) {
                if score != nil {
                    rankingView
                    scoreListView
                } else {
                    ProgressView()
                }
            }
        }
        .asyncStatusMask(status: status)
        .refreshable {
            _score.userTriggeredRefresh()
        }
        .onReceive(_score.$status, perform: {
            status = $0
        })
        .sheet(isPresented: $showSettings) { sheet }
        .padding([.leading, .trailing])
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
}

extension ScoreView {
    var sortedScore: [(name: String, courses: [CourseScore])] {
        score.courses.filter { course in
            !semesterNameToRemove.contains(course.semesterName)
        }.sorted(by: { lhs, rhs in
            switch sortPreference {
            case .none:
                return true
            case let .some(wrapped):
                switch wrapped {
                case .gpa:
                    return (lhs.gpa ?? 0) > (rhs.gpa ?? 0)
                case .code:
                    return lhs.lessonCode < rhs.lessonCode
                }
            }
        }).categorise { course in
            course.semesterName
        }.sorted(by: { lhs, rhs in
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
            }.map {
                $0.prefix(6)
            }.joined(separator: ", ")
        )
    }
}

extension ScoreView {
    var semesterButton: some View {
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
            Label("Semester: \(selectedSemesterNames)",
                  systemImage: "square.dashed.inset.filled")
                .lineLimit(1)
                .hStackLeading()
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
                Label("Sort by: \(sortPreference!.rawValue.localized)", systemImage: "number.square")
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
