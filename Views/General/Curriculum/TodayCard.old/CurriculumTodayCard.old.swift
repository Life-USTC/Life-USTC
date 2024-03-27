//
//  CurriculumTodayCard.old.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/28.
//

import SwiftUI

struct CurriculumTodayCard_old: View {
    @ManagedData(.curriculum) var curriculum: Curriculum

    var _date: Date = .now

    var date: Date { _date.stripTime() }

    var todayLectures: [Lecture] {
        curriculum.semesters.flatMap(\.courses).flatMap(\.lectures)
            .filter {
                (date ..< date.add(day: 1)).contains($0.startDate)
            }
            .sort()
    }

    var body: some View {
        CurriculumTodayView_old(
            lectures: todayLectures
        )
        .asyncStatusOverlay(
            _curriculum.status,
            text: "Curriculum",
            showLight: false,
            showToolbar: true
        )
        .card()
    }
}

#Preview {
    CurriculumTodayCard_old()
}
