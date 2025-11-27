//
//  LectureSheetModifier.swift
//  Life@USTC
//
//  Created by TianKai Ma on 2024/4/15.
//

import SwiftData
import SwiftUI
import SwiftyJSON

struct LectureSheetModifier: ViewModifier {
    var lecture: Lecture
    @State var showPopUp: Bool = false
    @Query(filter: #Predicate<KVStore> { $0.key == "buildingImgMapping" }) var mappingKV: [KVStore]

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
                                                    .fill((lecture.course?.color ?? .accentColor).opacity(0.2))
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
                        .padding([.top, .horizontal])

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

                        Spacer()
                    }
                }
                .presentationDetents([.fraction(0.45)])
                .task {
                    if mappingKV.first?.blob == nil { try? await BuildingImgMappingRepository.refresh() }
                }
            }
    }
}

extension View {
    func lectureSheet(lecture: Lecture) -> some View {
        modifier(LectureSheetModifier(lecture: lecture))
    }
}

extension LectureSheetModifier {
    fileprivate var buildingImageURL: URL? {
        guard let blob = mappingKV.first?.blob else { return nil }
        guard let json = try? JSON(data: blob) else { return nil }
        let rules = json.arrayValue.map {
            BuildingImgRule(regex: $0["regex"].stringValue, path: $0["path"].stringValue)
        }
        if let rule = rules.first(where: { lecture.location.range(of: $0.regex, options: .regularExpression) != nil }) {
            return SchoolSystem.current.buildingimgBaseURL.appendingPathComponent(rule.path)
        }
        return nil
    }
}
