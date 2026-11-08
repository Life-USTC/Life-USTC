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
    static var todayStart: Date { ProductCalendar.dayStart(referenceDate) }
    static var tomorrowStart: Date { ProductCalendar.addingDays(1, to: todayStart) }
    static var dayAfterTomorrowStart: Date { ProductCalendar.addingDays(2, to: todayStart) }

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
                try await Curriculum.update()
            }
        }
    }
}
