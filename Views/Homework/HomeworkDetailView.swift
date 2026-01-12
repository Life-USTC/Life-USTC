//
//  HomeworkDetailView.swift
//  Life@USTC
//
//  Created by TianKai Ma on 2023/12/1.
//

import SwiftData
import SwiftUI

private struct HomeworkView: View {
    let homework: Homework

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading) {
                Text(homework.title)
                    .font(.system(.title2, weight: .bold))
                    .foregroundColor(homework.isFinished ? .gray : .primary)

                Text(homework.courseName)
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Spacer(minLength: 25)

                HStack {
                    Image(systemName: "calendar.badge.clock")
                    Text(homework.dueDate, style: .date)
                    Text(homework.dueDate, style: .time)
                }
                .font(.callout)
            }

            Spacer()

            if homework.isFinished {
                Text("Finished")
                    .fontWeight(.bold)
                    .foregroundColor(.gray)

            } else {
                Text(homework.dueDate, style: .relative)
                    .fontWeight(.bold)
                    .foregroundColor(
                        homework.daysLeft <= 1 ? .red : homework.color
                    )
            }
        }
        .padding(.vertical, 2)
    }
}

struct HomeworkDetailView: View {
    @Query(sort: \Homework.dueDate, order: .forward) var _homeworks: [Homework]

    var homeworks: [Homework] {
        _homeworks.staged()
    }

    var body: some View {
        List {
            Section {
                if homeworks.isEmpty {
                    ContentUnavailableView(
                        "No Homework",
                        systemImage: "checkmark.seal.fill"
                    )
                } else {
                    ForEach(homeworks) { homework in
                        HomeworkView(homework: homework)
                    }
                }
            } header: {
                EmptyView()
            } footer: {
                Text("disclaimer")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Homework (BB)")
        .task {
            Task {
                try await Homework.update()
            }
        }
        .refreshable {
            Task {
                try await Homework.update()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        try await Homework.update()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}
