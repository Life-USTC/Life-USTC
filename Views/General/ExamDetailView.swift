//
//  ExamDetailView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import SwiftData
import SwiftUI

private struct ExamView: View {
    let exam: Exam

    var basicInfoView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                Text("\(exam.courseName)")
                    .font(.system(.title2, weight: .medium))
                    .strikethrough(exam.isFinished)
                    .foregroundColor(exam.isFinished ? .gray : .primary)
                    .background {
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: geo.size.width + 10, height: geo.size.height / 2)
                                .offset(x: -5, y: geo.size.height / 2)
                        }
                    }

                Text("\(exam.lessonCode)")
                    .font(.system(.subheadline, design: .monospaced, weight: .light))
                    .foregroundColor(.gray)
            }

            Spacer()

            Text("\(exam.typeName)")
                .font(.system(.subheadline, design: .monospaced, weight: .light))
                .foregroundColor(.gray)
        }
    }

    var timeInfoView: some View {
        Group {
            if exam.isFinished {
                Text("Finished")
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
            } else {
                Text(exam.startDate, style: .relative)
                    .fontWeight(.bold)
                    .foregroundColor(
                        exam.daysLeft <= 7 ? .red : .accentColor
                    )
            }
        }
    }

    var detailView: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Image(systemName: "location.fill.viewfinder")
                    Text(exam.detailLocation)
                }

                HStack(alignment: .top) {
                    Image(systemName: "calendar.badge.clock")
                    VStack(alignment: .leading) {
                        Text(exam.startDate, style: .date)
                        Text(exam.startDate ... exam.endDate)
                    }
                    Spacer()
                }
            }
            .font(.footnote)

            timeInfoView
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            basicInfoView
            detailView
        }
    }
}

struct ExamDetailView: View {
    @Query(sort: \Exam.startDate, order: .forward) var exams: [Exam]

    var body: some View {
        List {
            Section {
                if exams.isEmpty {
                    ContentUnavailableView("No Exam", image: "calendar")
                } else {
                    ForEach(exams.clean()) { exam in
                        ExamView(exam: exam)
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
        .refreshable {
            Task {
                try await Exam.update()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        try? await CalendarSaveHelper.saveExams()
                    }
                } label: {
                    Label("Save to Calendar", systemImage: "calendar.badge.plus")
                }
            }
        }
        .navigationTitle("Exam")
        .task {
            Task {
                try await Exam.update()
            }
        }
    }
}
