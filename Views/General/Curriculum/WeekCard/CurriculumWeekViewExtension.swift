//
//  CurriculumWeekViewExtension.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/25.
//

import SwiftUI

extension CurriculumWeekCard {
    var settingsView: some View {
        VStack(alignment: .leading) {
            topBar

            Spacer()
                .frame(height: 20)

            DatePicker(selection: $_date, displayedComponents: .date) {
                VStack(alignment: .leading) {
                    Text("Date")

                    Text("You can also swipe left/right to switch weeks")
                        .font(.system(.caption, weight: .light))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading) {
                    Text("Semester")

                    Text(
                        "Semester selection is automatically updated based on current date"
                    )
                    .font(.system(.caption, weight: .light))
                    .foregroundColor(.secondary)
                }

                Spacer()

                Menu {
                    ForEach(curriculum.semesters) { semester in
                        Button(semester.name) {
                            currentSemester = semester
                        }
                    }
                    Button("All") { currentSemester = nil }
                } label: {
                    Text(currentSemester?.name ?? "All")
                }
            }

            Divider()

            Spacer()
        }
    }
}

extension CurriculumWeekCard {
    func updateLecturesAndWeekNumber() {
        lectures =
            (currentSemester == nil
            ? curriculum.semesters.flatMap { $0.courses.flatMap(\.lectures) }
            : currentSemester!.courses.flatMap(\.lectures))
            .filter {
                (0.0 ..< 3600.0 * 24 * 7)
                    .contains($0.startDate.stripTime().timeIntervalSince(date))
            }

        if let currentSemester {
            weekNumber =
                (Calendar(identifier: .gregorian)
                    .dateComponents(
                        [.weekOfYear],
                        from: currentSemester.startDate,
                        to: date
                    )
                    .weekOfYear ?? 0) + 1
        }
    }

    func updateSemester() {
        currentSemester =
            curriculum.semesters
            .filter {
                ($0.startDate ... $0.endDate).contains(_date)
            }
            .first
    }
}
