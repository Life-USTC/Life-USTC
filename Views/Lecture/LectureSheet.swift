//
//  LectureSheetModifier.swift
//  Life@USTC
//
//  Created by TianKai Ma on 2024/4/15.
//

import SwiftData
import SwiftUI
import SwiftyJSON

struct LectureSheetView: View {
    var lecture: Lecture

    @State var buildingImageURL: URL? = nil

    var body: some View {
        NavigationStack {
            VStack {
                HStack(alignment: .bottom) {
                    lectureInfoSection
                    Spacer()
                    courseDetailsSection
                }
                .padding([.top, .horizontal])

                buildingImageSection

                Spacer()
            }
        }
        .presentationDetents([.fraction(0.45)])
        .task {
            buildingImageURL = try? await BuildingImgMapping.getImageURL(for: lecture.location)
        }
    }

    var lectureInfoSection: some View {
        VStack(alignment: .leading) {
            titleView

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
    }

    var titleView: some View {
        Text(lecture.name)
            .font(.title)
            .fontWeight(.medium)
            .background {
                GeometryReader { geo in
                    Rectangle()
                        .fill((lecture.course?.color ?? .accentColor).opacity(0.2))
                        .frame(width: geo.size.width + 10, height: geo.size.height / 2)
                        .offset(x: -5, y: geo.size.height / 2)
                }
            }
    }

    var courseDetailsSection: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .bottom) {
                Text("Teacher: ")
                    .foregroundStyle(.secondary)
                Text(lecture.teacherName)
                    .lineLimit(1)
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

    @ViewBuilder
    var buildingImageSection: some View {
        if let url = buildingImageURL {
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
    }
}

struct LectureSheetModifier: ViewModifier {
    var lecture: Lecture

    @State var showPopUp: Bool = false

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                showPopUp = true
            }
            .sheet(isPresented: $showPopUp) {
                LectureSheetView(lecture: lecture)
            }
    }
}

extension View {
    func lectureSheet(lecture: Lecture) -> some View {
        modifier(LectureSheetModifier(lecture: lecture))
    }
}
