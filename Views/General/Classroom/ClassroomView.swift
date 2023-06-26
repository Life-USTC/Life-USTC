//
//  ClassroomView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/15.
//

import SwiftUI

private let baseStart = timeToInt("7:50")
private let baseMiddle = timeToInt("12:30")
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
        RoundedRectangle(cornerRadius: 5)
            .fill(lesson.color)
            .opacity(0.5)
            .overlay {
                Text(lesson.courseName)
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(lineWidth: 0.3)
                    .fill(Color.secondary)
            )
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
                    .navigationBarTitle("Details", displayMode: .inline)
                    .listStyle(.plain)
                }
                .presentationDetents([.fraction(0.3)])
            }
    }
}

private struct SingleClassroomView: View {
    @AppStorage("showOneLine") var showOneLine = true
    @State var highlighted = false
    var room: String
    var status: Bool
    var lessons: [Lesson]

    func makeView(with lessons: [Lesson], isUp: Bool) -> some View {
        let start = isUp ? baseStart : baseMiddle
        let end = isUp ? baseMiddle : baseEnd
        let filteredClass = Lesson.clean(lessons.filter { isUp ? (timeToInt($0.startTime) < baseMiddle) : (timeToInt($0.endTime) > baseMiddle) })

        return GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(.gray.opacity(0.4))
                    .opacity(isUp ? 0.7 : 0.3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(lineWidth: 0.5)
                            .fill(Color.secondary)
                    )
                ForEach(filteredClass) { lesson in
                    LessonView(lesson: lesson)
                        .frame(width: geo.size.width * Double(timeToInt(lesson.endTime) - timeToInt(lesson.startTime)) / Double(end - start))
                        .offset(x: -Double(end + start - timeToInt(lesson.endTime) - timeToInt(lesson.startTime)) / Double(end - start) / 2.0 * geo.size.width)
                }
                Rectangle()
                    .fill(.background)
                    .frame(width: 5, height: geo.size.height)
                    .offset(x: Double(currentTimeInt - (end + start) / 2) / Double(end - start) * geo.size.width)
            }
        }
        .frame(height: 20)
    }

    var roomText: some View {
        Text(room)
            .font(.system(size: 10, design: .monospaced))
            .lineLimit(1)
            .foregroundColor(status ? .green : .primary)
    }

    var body: some View {
        if showOneLine {
            HStack {
                roomText
                makeView(with: lessons, isUp: currentTimeInt <= baseMiddle)
            }
        } else {
            VStack(spacing: 2) {
                HStack {
                    roomText
                    makeView(with: lessons, isUp: true)
                }
                makeView(with: lessons, isUp: false)
            }
        }
    }
}

struct ClassroomView: View {
    @StateObject var ustcCatalogDelegate = UstcCatalogClient.shared
    var allLessons: [String: [Lesson]] {
        ustcCatalogDelegate.data
    }

    var status: AsyncViewStatus {
        ustcCatalogDelegate.status
    }

    @State var showSheet: Bool = false
    @State var date = Date()
    @AppStorage("showOneLine") var showOneLine = true
    @AppStorage("showEmptyRoomOnly") var showEmptyRoomOnly = false
    @AppStorage("filteredBuildingList") var filteredBuildingList: [String] = []

    func filterLesson(building: String, room: String) -> [Lesson] {
        allLessons[building]?.filter { $0.classroomName == room } ?? []
    }

    func statusFor(building: String, room: String) -> Bool {
        filterLesson(building: building, room: room).first(where: { timeToInt($0.startTime) <= currentTimeInt && currentTimeInt <= timeToInt($0.endTime) }) == nil
    }

    func makeView(with building: String) -> some View {
        VStack(spacing: showOneLine ? 2 : 5) {
            ForEach(UstcCatalogClient.buildingRooms[building] ?? [], id: \.self) { room in
                if !showEmptyRoomOnly || statusFor(building: building, room: room) {
                    SingleClassroomView(room: room, status: statusFor(building: building, room: room), lessons: filterLesson(building: building, room: room))
                }
            }
        }
    }

    func settingSheet() -> some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Pick a date", selection: $date, displayedComponents: [.date])
                        .onChange(of: date) { newDate in
                            ustcCatalogDelegate.date = newDate
                        }
                    Toggle("Show empty room only", isOn: $showEmptyRoomOnly)
                    Toggle("Show one line", isOn: $showOneLine)
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

    private let labels: [(text: String, color: Color)] = [("Lesson", .blue),
                                                          ("Temp", .green),
                                                          ("Exam", .red)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            HStack {
                Spacer()
                ForEach(labels, id: \.text) { label in
                    Text(label.text.localized)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(label.color.opacity(0.7))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(lineWidth: 0.3)
                                        .fill(Color.secondary)
                                )
                        )
                }
            }
            ForEach(UstcCatalogClient.allBuildings, id: \.self) { building in
                if !filteredBuildingList.contains(building) {
                    Text(UstcCatalogClient.buildingName(with: building))
                        .font(.title3)
                        .padding()
                        .hStackLeading()
                    makeView(with: building)
                }
            }
        }
        .asyncViewStatusMask(status: status)
        .padding(.horizontal, 5)
        .navigationBarTitle("Classroom List", displayMode: .inline)
        .toolbar {
            if status == .inProgress {
                ProgressView()
            }

            Button {
                showSheet = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .sheet(isPresented: $showSheet, content: settingSheet)
    }
}
