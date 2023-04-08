//
//  CurriculumPreview.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import SwiftUI

struct CurriculumPreview: View {
    var body: some View {
        AsyncView(delegate: CurriculumDelegate.shared, showReloadButton: false) { courses in
            let todayCourse = courses.filter { $0.dayOfWeek == currentWeekDay }.sorted(by: { $0.startTime < $1.startTime })
            if todayCourse.isEmpty {
                return happyView
            } else {
                return makeView(with: todayCourse)
            }
        }
    }

    func makeView(with courses: [Course]) -> some View {
        VStack(spacing: 0) {
            ForEach(courses) { course in
                ZStack {
                    GeometryReader { geo in
                        RectangleProgressBar(
                            height: geo.size.height,
                            width: geo.size.width,
                            startDate: Date().stripTime() + Course.startTimes[course.startTime - 1],
                            endDate: Date().stripTime() + Course.endTimes[course.endTime - 1],
                            color: .black
                        )
                    }
                    .frame(height: 50)
                    HStack {
                        VStack(alignment: .leading) {
                            Text(course.name)
                            Text(course.classPositionString)
                                .font(.subheadline)
                        }
                        Spacer()
                        Text(course.clockTime)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .blendMode(.exclusion)
                    .padding(.horizontal)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    /// If no class are shown...
    var happyView: some View {
        HStack {
            Text("Free today!")
                .font(.title3)
                .fontWeight(.bold)

            Spacer()

            Image(systemName: "calendar.badge.clock")
                .fontWeight(.light)
                .font(.largeTitle)
        }
        .foregroundColor(.white)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: exampleGradientList.randomElement() ?? [],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
        }
    }
}

struct CurriculumPreview_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            VStack {
                CurriculumPreview()
                    .happyView

                CurriculumPreview().makeView(with: [.example, .example])
            }
            .padding()
        }
    }
}
