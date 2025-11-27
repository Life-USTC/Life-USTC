//
//  CurriculumPreviewCard.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/26.
//

import SwiftData
import SwiftUI

struct CurriculumPreviewCard: View {
    @Query(sort: \Semester.startDate, order: .forward) var semesters: [Semester]

    var referenceDate: Date = .now

    var date: Date { referenceDate.stripTime() }

    var allLectures: [Lecture] {
        semesters.flatMap { $0.courses }.flatMap { $0.lectures }
    }

    var todayLectures: [Lecture] {
        allLectures
            .filter { (date ..< date.add(day: 1)).contains($0.startDate) }
            .sort()
            .union()
    }

    var tomorrowLectures: [Lecture] {
        allLectures
            .filter { (date.add(day: 1) ..< date.add(day: 2)).contains($0.startDate) }
            .sort()
            .union()
    }

    var body: some View {
        VStack(spacing: 15) {
            Text("Curriculum")
                .font(.system(.title2, weight: .medium))
                .hStackLeading()

            CurriculumPreview(
                lectureListA: todayLectures,
                lectureListB: tomorrowLectures
            )
        }
        .card()
        .task { await refresh() }
    }

    private func refresh() async {
        try? await CurriculumRepository.refresh()
    }
}
