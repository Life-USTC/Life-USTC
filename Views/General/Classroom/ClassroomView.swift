//
//  ClassroomView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/15.
//

import SwiftUI

private let baseStart = timeToInt("7:50")
private let baseEnd = timeToInt("21:55")

private var currentTimeInt: Int {
    let date = Date()
    let calendar = Calendar.current
    return calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
}

private struct LessonView: View {
    @State var showSheet: Bool = false
    let lesson: Lesson

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .opacity(0.5)
            .foregroundColor(lesson.color ?? .red)
            .overlay {
                Text(lesson.courseName)
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            }
            .onTapGesture {}
            .onLongPressGesture {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                showSheet = true
            }
            .sheet(isPresented: $showSheet) {
                NavigationStack {
                    List {
                        Text("Lesson name: ".localized + lesson.courseName)
                        Text("Classroom: ".localized + lesson.classroomName)
                        Text("Duration: ".localized + lesson.startTime + "->" + lesson.endTime)
                    }
                    .foregroundColor(.primary)
                    .navigationTitle("Details")
                    .navigationBarTitleDisplayMode(.inline)
                    .listStyle(.plain)
                }
                .presentationDetents([.fraction(0.3)])
            }
    }
}

struct ClassroomView: View {
    @State var allLessons: [String: [Lesson]] = [:]
    @State var status: AsyncViewStatus = .inProgress
    @State var showSheet: Bool = false
    @State var date: Date = .init()
    @AppStorage("showEmptyRoomOnly") var showEmptyRoomOnly = false
    @AppStorage("filteredBuildingList") var filteredBuildingList: [String] = []

    func filterLesson(building: String, room: String) -> [Lesson] {
        return allLessons[building]?.filter { $0.classroomName == room } ?? []
    }

    func statusFor(building: String, room: String) -> Bool {
        return filterLesson(building: building, room: room).first(where: { timeToInt($0.startTime) <= currentTimeInt && currentTimeInt <= timeToInt($0.endTime) }) == nil
    }

    func makeView(with building: String) -> some View {
        ForEach(UstcCatalogClient.buildingRooms[building] ?? [], id: \.self) { room in
            if !showEmptyRoomOnly || statusFor(building: building, room: room) {
                HStack {
                    Text(room)
                        .font(.system(size: 10, design: .monospaced))
                        .lineLimit(1)
                        .foregroundColor(statusFor(building: building, room: room) ? .green : .primary)

                    GeometryReader { geo in
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .foregroundColor(.init(uiColor: .lightGray))
                                .opacity(0.5)
                            ForEach(filterLesson(building: building, room: room)) { lesson in
                                LessonView(lesson: lesson)
                                    .frame(width: geo.size.width * Double(timeToInt(lesson.endTime) - timeToInt(lesson.startTime)) / Double(baseEnd - baseStart))
                                    .offset(x: -Double(baseEnd + baseStart - timeToInt(lesson.endTime) - timeToInt(lesson.startTime)) / Double(baseEnd - baseStart) / 2.0 * geo.size.width)
                            }
                            Rectangle()
                                .foregroundColor(.green)
                                .opacity(0.5)
                                .frame(width: 5, height: geo.size.height)
                                .offset(x: Double(currentTimeInt - (baseEnd + baseStart) / 2) / Double(baseEnd - baseStart) * geo.size.width)
                        }
                    }
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(UstcCatalogClient.allBuildings, id: \.self) { building in
                        if !filteredBuildingList.contains(building) {
                            Text(UstcCatalogClient.buildingName(with: building))
                                .font(.title3)
                                .padding()
                            makeView(with: building)
                        }
                    }
                }
            }
            .onAppear {
                asyncBind($allLessons, status: $status) {
                    try await UstcCatalogClient.main.queryAllClassrooms()
                }
            }
            .padding([.leading, .trailing], 2)
            .navigationTitle("Classroom List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if status == .inProgress {
                        ProgressView()
                    }

                    Button {
                        showSheet = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSheet) {
                NavigationStack {
                    List {
                        Section {
                            DatePicker("Pick a date", selection: $date, displayedComponents: [.date])
                                .onChange(of: date) { newDate in
                                    print("Updated")
                                    asyncBind($allLessons, status: $status) {
                                        try await UstcCatalogClient.main.queryAllClassrooms(date: newDate)
                                    }
                                }
                            Toggle("Show empty room only", isOn: $showEmptyRoomOnly)
                        } header: {
                            Text("General")
                        }

                        Section {
                            ForEach(UstcCatalogClient.allBuildings, id: \.self) { building in
                                Button {
                                    if filteredBuildingList.contains(building) {
                                        filteredBuildingList.removeAll(where: { $0 == building })
                                    } else {
                                        filteredBuildingList.append(building)
                                    }
                                } label: {
                                    HStack {
                                        Text(UstcCatalogClient.buildingName(with: building))
                                            .foregroundColor(.primary)
                                        if !filteredBuildingList.contains(building) {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } header: {
                            Text("Buildings to show")
                        }
                    }
                    .navigationTitle("Settings")
                }
            }
        }
    }
}
