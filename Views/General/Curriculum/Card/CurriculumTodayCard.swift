//
//  CurriculumTodayCard.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/26.
//

import SwiftUI

struct CurriculumTodayCard: View {
    @ManagedData(.curriculum) var curriculum: Curriculum

    var _date: Date = .now

    var date: Date { _date.stripTime() }

    var todayLectures: [Lecture] {
        curriculum.semesters.flatMap(\.courses).flatMap(\.lectures)
            .filter {
                (date ..< date.add(day: 1)).contains($0.startDate)
            }
            .sort()
            .union()
    }

    var tomorrowLectures: [Lecture] {
        curriculum.semesters.flatMap(\.courses).flatMap(\.lectures)
            .filter {
                (date.add(day: 1) ..< date.add(day: 2)).contains($0.startDate)
            }
            .sort()
            .union()
    }

    var body: some View {
        VStack {
            HStack {
                Text("Curriculum")
                    .font(.system(.title2, weight: .medium))
                Spacer()
            }
            CurriculumTodayView(
                lectureListA: todayLectures,
                lectureListB: tomorrowLectures
            )
        }
        .card()
    }
}
