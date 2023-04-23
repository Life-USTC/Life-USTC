//
//  CurriculumPreview.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import SwiftUI

struct RandomNumberGeneratorWithSeed: RandomNumberGenerator {
    init(seed: Int) { srand48(seed) }
    func next() -> UInt64 { UInt64(drand48() * Double(UInt64.max)) }
}

struct CurriculumPreview: View {
    var body: some View {
        AsyncView(delegate: CurriculumDelegate.shared, showReloadButton: false) { courses in
            let todayCourse = courses.filter { $0.dayOfWeek % 7 == currentWeekDay }.sorted(by: { $0.startTime < $1.startTime })
            if todayCourse.isEmpty {
                return happyView
            } else {
                return makeView(with: todayCourse)
            }
        }
    }

    func makeView(with courses: [Course]) -> some View {
        VStack(spacing: 2) {
            ForEach(courses) { course in
                GeometryReader { geo in
                    RectangleProgressBar(
                        width: geo.size.width,
                        height: geo.size.height,
                        course: course
                    )
                }
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
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

var exampleCourse: Course {
    var result = Course.example

    result.startTime = 1
    result.endTime = 10

    return result
}

struct CurriculumPreview_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            VStack {
                CurriculumPreview()
                    .happyView
                CurriculumPreview()
                    .makeView(with: [exampleCourse, exampleCourse])
            }
            .padding()
        }
    }
}
