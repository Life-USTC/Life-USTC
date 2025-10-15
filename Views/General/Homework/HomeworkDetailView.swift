//
//  HomeworkDetailView.swift
//  学在科大
//
//  Created by TianKai Ma on 2023/12/1.
//

import SwiftUI

struct HomeworkDetailView: View {
    @ManagedData(.homework) var homeworks: [Homework]

    var archivedHomework: [Homework] {
        homeworks.filter { $0.dueDate < Date() }.sorted { $0.dueDate > $1.dueDate }
    }

    var newHomework: [Homework] {
        homeworks.filter { $0.dueDate > Date() }.sorted { $0.dueDate < $1.dueDate }
    }

    var body: some View {
        List {
            Section {
                if homeworks.isEmpty {
                    SingleHomeWorkView(homework: .example)
                        .redacted(reason: .placeholder)
                        .overlay(
                            Text("No More Homework!")
                                .font(.system(.body, design: .monospaced))
                                .padding(.vertical, 10)
                        )
                } else {
                    ForEach(newHomework) { homework in
                        SingleHomeWorkView(homework: homework)
                    }

                    ForEach(archivedHomework) { homework in
                        SingleHomeWorkView(homework: homework)
                    }
                }
            } header: {
                AsyncStatusLight(status: _homeworks.status)
            } footer: {
                Text("disclaimer")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .asyncStatusOverlay(_homeworks.status)
        .padding(.horizontal)
        .refreshable {
            _homeworks.triggerRefresh()
        }
        .navigationTitle("Homework (Blackboard)")
        .navigationBarTitleDisplayMode(.inline)
    }

}
