//
//  CurriculumPreview.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import SwiftUI

struct CurriculumPreview: View {
    var body: some View {
        AsyncView { courses in
            let todayCourse = courses.filter { $0.dayOfWeek == currentWeekDay }
            if todayCourse.isEmpty {
                return happyView
            } else {
                return makeView(with: todayCourse)
            }
        } loadData: {
            try await UstcUgAASClient.main.getCurriculum()
        }
    }

    func makeView(with courses: [Course]) -> some View {
        VStack {
            ForEach(courses) { course in
                HStack {
                    TitleAndSubTitle(title: course.name, subTitle: course.classPositionString, style: .substring)
                    Spacer()
                    Text(Course.startTimes[course.startTime - 1].clockTime + " - " + Course.endTimes[course.endTime - 1].clockTime)
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
