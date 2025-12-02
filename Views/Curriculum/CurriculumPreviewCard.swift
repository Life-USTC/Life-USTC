//
//  CurriculumPreviewCard.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/26.
//

import SwiftData
import SwiftUI

struct CurriculumPreviewCard: View {
    static var referenceDate: Date { Date() }
    static var todayStart: Date { referenceDate.stripTime() }
    static var tomorrowStart: Date { todayStart.add(day: 1) }
    static var dayAfterTomorrowStart: Date { todayStart.add(day: 2) }

    @Query(
        filter: #Predicate<Lecture> { lecture in
            todayStart <= lecture.startDate && lecture.startDate < tomorrowStart
        },
        sort: [SortDescriptor(\Lecture.startDate, order: .forward)]
    ) var todayLectures: [Lecture]

    @Query(
        filter: #Predicate<Lecture> { lecture in
            tomorrowStart <= lecture.startDate && lecture.startDate < dayAfterTomorrowStart
        },
        sort: [SortDescriptor(\Lecture.startDate, order: .forward)]
    ) var tomorrowLectures: [Lecture]

    var body: some View {
        VStack(spacing: 15) {
            Text("Curriculum")
                .font(.system(.title2, weight: .medium))
                .hStackLeading()

            CurriculumPreview(
                todayLectures: todayLectures,
                tomorrowLectures: tomorrowLectures
            )
        }
        .card()
        .task {
            Task {
                try await SchoolSystem.current.updateCurriculum()
            }
        }
    }
}
