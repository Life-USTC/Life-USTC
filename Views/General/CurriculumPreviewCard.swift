//
//  CurriculumPreviewCard.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/26.
//

import SwiftUI

struct CurriculumPreviewCard: View {
    @ManagedData(.curriculum) var curriculum: Curriculum

    var referenceDate: Date = .now

    var date: Date { referenceDate.stripTime() }

    var allLectures: [Lecture] {
        curriculum.semesters.flatMap(\.courses).flatMap(\.lectures)
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
            .asyncStatusOverlay(_curriculum.status)
        }
        .card()
    }
}
