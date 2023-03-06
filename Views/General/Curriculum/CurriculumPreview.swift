//
//  CurriculumPreview.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import SwiftUI

struct CurriculumPreview: View {
    var body: some View {
        AsyncView(delegate: UstcUgAASClient.curriculumDelegate, showReloadButton: false) { courses in
            let todayCourse = courses.filter { $0.dayOfWeek == currentWeekDay }.sorted(by: { $0.startTime < $1.startTime })
            if todayCourse.isEmpty {
                return happyView
            } else {
                return makeView(with: todayCourse)
            }
        }
    }

    func makeView(with courses: [Course]) -> some View {
        VStack {
            ForEach(courses) { course in
                HStack {
                    VStack(alignment: .leading) {
                        Text(course.name)
                        Text(course.classPositionString)
                            .font(.subheadline)
                            .foregroundColor(Color.gray)
                    }
                    Spacer()
                    Text(Course.startTimes[course.startTime - 1].clockTime + " - " + Course.endTimes[course.endTime - 1].clockTime)
                        .fontWeight(.bold)
                }
                Divider()
            }
        }
    }

    /// If no class are shown...
    var happyView: some View {
        VStack {
            Image(systemName: "signature")
                .foregroundColor(.accentColor)
                .font(.system(size: 40))
            Text("Free today!")
        }
    }
}
