//
//  CurriculumPreview.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import SwiftUI

struct CurriculumPreview: View {
    @State var courses: [Course] = []
    @State var status: AsyncViewStatus = .inProgress
    var todayCourse: [Course] {
        courses.filter { course in
            course.dayOfWeek == currentWeekDay
        }
    }

    var body: some View {
        Group {
            if status == .inProgress {
                ProgressView()
            } else {
                if todayCourse.isEmpty {
                    happyView
                } else {
                    mainView
                }
            }
        }
        .frame(width: cardWidth)
        .onAppear {
            asyncBind($courses, status: $status) {
                try await UstcUgAASClient.main.getCurriculum()
            }
        }
    }

    var mainView: some View {
        List {
            ForEach(todayCourse) { course in
                HStack {
                    TitleAndSubTitle(title: course.name, subTitle: course.classPositionString, style: .substring)
                    Spacer()
                    Text(Course.startTimes[course.startTime - 1].clockTime + " - " + Course.endTimes[course.endTime - 1].clockTime)
                }
            }
        }
        .listStyle(.plain)
        .frame(height: cardHeight / 3 * Double(todayCourse.count))
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
