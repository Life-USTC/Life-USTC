//
//  LectureCardView.swift
//  学在科大
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
                                    Text("Teacher: ".localized)
                                        .foregroundStyle(.secondary)
                                    Text(lecture.teacherName)
                                }
                                if let credit = lecture.course?.credit {
                                    HStack(alignment: .bottom) {
                                        Text("Credit: ".localized)
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

struct LectureCardView: View {
    var lecture: Lecture

    var length: Int {
        (lecture.endIndex ?? 0) - (lecture.startIndex ?? 0) + 1
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 5)
                .fill(lecture.course?.color().opacity(0.1) ?? Color.blue.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(lecture.startDate.clockTime)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))

                Group {
                    Text(lecture.name)
                        .font(.system(size: 15, weight: .light))
                        .lineLimit(2, reservesSpace: false)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.01)
                    Text(lecture.location)
                        .font(.system(size: 13, weight: .light, design: .monospaced))
                        .lineLimit(2, reservesSpace: false)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.01)
                }

                Spacer()

                if length > 1 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(lecture.teacherName)
                            .font(.system(size: 10))
                            .lineLimit(2, reservesSpace: false)
                            .multilineTextAlignment(.trailing)
                            .minimumScaleFactor(0.01)

                        Text(lecture.endDate.clockTime)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .hStackTrailing()
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
        }
        .lectureSheet(lecture: lecture)
    }
}
