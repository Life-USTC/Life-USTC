//
//  LectureSheetModifier.swift
//  Life@USTC
//
//  Created by TianKai Ma on 2024/4/15.
//

import SwiftUI

struct LectureSheetModifier: ViewModifier {
    var lecture: Lecture
    @State var showPopUp: Bool = false
    @ManagedData(.buildingImgMapping) var buildingImgMapping

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                showPopUp = true
            }
            .sheet(isPresented: $showPopUp) {
                NavigationStack {
                    VStack {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading) {
                                HStack(alignment: .bottom) {
                                    Text(lecture.name)
                                        .font(.title)
                                        .fontWeight(.medium)
                                        .background {
                                            GeometryReader { geo in
                                                Rectangle()
                                                    .fill((lecture.course?.color() ?? .accentColor).opacity(0.2))
                                                    .frame(width: geo.size.width + 10, height: geo.size.height / 2)
                                                    .offset(x: -5, y: geo.size.height / 2)
                                            }
                                        }
                                }
                                HStack {
                                    Text(lecture.startDate.clockTime + "-" + lecture.endDate.clockTime)
                                    if let startIndex = lecture.startIndex, let endIndex = lecture.endIndex {
                                        Text("(\(startIndex)-\(endIndex))")
                                    }
                                }
                                .foregroundStyle(.secondary)
                                .bold()

                                Text("@" + lecture.location)
                                    .foregroundStyle(.secondary)
                                    .bold()
                            }

                            Spacer()

                            VStack(alignment: .leading) {
                                HStack(alignment: .bottom) {
                                    Text("Teacher: ")
                                        .foregroundStyle(.secondary)
                                    Text(lecture.teacherName)
                                }
                                if let credit = lecture.course?.credit {
                                    HStack(alignment: .bottom) {
                                        Text("Credit: ")
                                            .foregroundStyle(.secondary)
                                        Text(String(credit))
                                    }
                                }
                                if let code = lecture.course?.lessonCode {
                                    Text(code)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .bold()
                                }
                            }
                            .font(.caption)
                        }
                        .padding([.top, .horizontal])

                        if let url = buildingImgMapping.getURL(buildingName: lecture.location) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(maxWidth: .infinity, maxHeight: 400)
                            .padding(5)
                        }

                        Spacer()
                    }
                }
                .presentationDetents([.fraction(0.45)])
            }
    }
}

extension View {
    func lectureSheet(lecture: Lecture) -> some View {
        modifier(LectureSheetModifier(lecture: lecture))
    }
}
