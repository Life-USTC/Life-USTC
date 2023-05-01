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
    @State var courses: [Course]? = nil
    @State var status: AsyncViewStatus = .inProgress
    @State var date = Date()
    var body: some View {
        Group {
            if courses != nil {
                if courses!.isEmpty {
                    happyView
                } else {
                    makeView(with: courses!)
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            Task {
                let weekNumber = await UstcUgAASClient.shared.weekNumber()
                // try await CurriculumDelegate.shared.forceUpdate()
                // courses = Course.filter((try await CurriculumDelegate.shared.parseCache()), week: weekNumber)
                CurriculumDelegate.shared.asyncBind(status: $status) {
                    self.courses = Course.filter($0, week: weekNumber)
                }
            }
        }
        .onChange(of: date) { _ in
            Task {
                let weekNumber = await UstcUgAASClient.shared.weekNumber(for: date)
                // try await CurriculumDelegate.shared.forceUpdate()
                // courses = Course.filter((try await CurriculumDelegate.shared.parseCache()), week: weekNumber)
                CurriculumDelegate.shared.asyncBind(status: $status) {
                    self.courses = Course.filter($0, week: weekNumber, weekday: weekday(for: date))
                }
            }
        }
#if DEBUG
            .toolbar {
                DatePicker(selection: $date, displayedComponents: .date) {}
            }
#endif
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
        .frame(height: 50)
    }
}

struct CourseStackView: View {
    @Binding var courses: [Course]
    var body: some View {
        VStack {
            ForEach(courses) { course in
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading) {
                            Text(course.name)
                                .fontWeight(.bold)
                            Text(course.classPositionString)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(course.clockTime)
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding(.horizontal, 5)
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(height: 5)
                }
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(style: .init(lineWidth: 1))
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(height: 50)
            }

            if courses.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "calendar")
                            .symbolRenderingMode(.hierarchical)
                            .fontWeight(.light)
                            .font(.largeTitle)
                            .foregroundColor(.orange)

                        Spacer()

                        Text("Nothing here")
                            .foregroundColor(.orange)
                            .opacity(0.6)
                    }
                    .padding(.horizontal, 10)
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.orange)
                        .frame(height: 5)
                }
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(style: .init(lineWidth: 1))
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(height: 50)
            }
        }
    }
}

var exampleCourse: Course {
    var result = Course.example

//    result.startTime = 1
//    result.endTime = 10

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
