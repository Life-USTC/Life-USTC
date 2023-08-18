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

struct CourseStackView: View {
    var courses: [Course]
    @State var randomColor = exampleGradientList.randomElement() ?? []
    var body: some View {
//        VStack {
//            ForEach(courses) { course in
//                VStack {
//                    Spacer()
//                    HStack {
//                        VStack(alignment: .leading) {
//                            Text(course.name.truncated(length: 10))
//                                .fontWeight(.bold)
//                                .lineLimit(1)
//                                .truncationMode(.tail)
//
//                            Text(course.roomName)
//                                .font(.caption)
//                                .foregroundColor(.secondary)
//                        }
//                        Spacer()
//                        Text(course.clockTime)
//                            .font(.system(.body, design: .monospaced))
//                    }
//                    .padding(.horizontal, 8)
//                    Spacer()
//                    RoundedRectangle(cornerRadius: 2)
//                        .fill(LinearGradient(colors: randomColor,
//                                             startPoint: .topLeading,
//                                             endPoint: .bottomTrailing))
//                        .frame(height: 5)
//                }
//                .background {
//                    RoundedRectangle(cornerRadius: 5)
//                        .stroke(style: .init(lineWidth: 1))
//                        .fill(Color.gray.opacity(0.3))
//                }
//                .frame(height: 60)
//            }
//
//            if courses.isEmpty {
//                VStack {
//                    Spacer()
//                    HStack {
//                        Image(systemName: "calendar")
//                            .symbolRenderingMode(.hierarchical)
//                            .fontWeight(.light)
//                            .font(.largeTitle)
//                            .foregroundColor(.orange)
//
//                        Spacer()
//
//                        Text("Nothing here")
//                            .font(.system(.body, design: .monospaced))
//                    }
//                    .padding(.horizontal, 8)
//                    Spacer()
//                    RoundedRectangle(cornerRadius: 2)
//                        .fill(Color.orange)
//                        .frame(height: 5)
//                }
//                .background {
//                    RoundedRectangle(cornerRadius: 5)
//                        .stroke(style: .init(lineWidth: 1))
//                        .fill(Color.gray.opacity(0.3))
//                }
//                .frame(height: 60)
//            }
//        }
        Text("TBC")
    }
}
