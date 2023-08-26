//
//  ClassroomView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/15.
//

import Charts
import SwiftUI

private enum ClassRoomColor: String {
    case blue
    case green
    case red

    var color: Color {
        switch self {
        case .blue: Color.blue
        case .green: Color.green
        case .red: Color.red
        }
    }
}

struct USTCClassroomView: View {
    enum Selection: String {
        case morning
        case afternoon
        case night
    }

    @ManagedData(.classroom) var classroom: [String: [Lecture]]
    @AppStorage("ustcClassroomSelectedDate") var _date: Date = .now
    @AppStorage("ustcClassroomSelectedBuilding") var selectedBuilding: String =
        "5"
    @State var selection: Selection = .morning

    var date: Date {
        _date.stripTime()
    }

    var dateRange: ClosedRange<Date> {
        switch selection {
        case .morning:
            return date + .init(hour: 7, minute: 50) ... date
                + .init(hour: 12, minute: 10)
        case .afternoon:
            return date + .init(hour: 14, minute: 0) ... date
                + .init(hour: 18, minute: 20)
        case .night:
            return date + .init(hour: 19, minute: 0) ... date
                + .init(hour: 21, minute: 50)
        }
    }

    var buildingName: String {
        ustcBuildingNames[selectedBuilding] ?? "Unknown"
    }

    var buildingRooms: [String] {
        ustcBuildingRooms[selectedBuilding] ?? []
    }

    var lectures: [Lecture] {
        classroom[selectedBuilding] ?? []
    }

    var body: some View {
        List {
            Section {
                DatePicker(
                    "Date",
                    selection: $_date,
                    displayedComponents: .date
                )
                HStack {
                    Text("Building")
                    Spacer()
                    Menu {
                        ForEach(Array(ustcBuildingNames.keys), id: \.self) {
                            building in
                            Button {
                                selectedBuilding = building
                            } label: {
                                Text(ustcBuildingNames[building] ?? "Unknown")
                            }
                        }
                    } label: {
                        Text(buildingName)
                    }
                }

                Chart {
                    ForEach(buildingRooms, id: \.self) { room in
                        BarMark(
                            xStart: .value("Start time", date),
                            xEnd: .value("End time", date.add(day: 1)),
                            y: .value("Room", room)
                        )
                        .foregroundStyle(.clear)
                    }

                    ForEach(lectures) { lecture in
                        BarMark(
                            xStart: .value("Start time", lecture.startDate),
                            xEnd: .value("End time", lecture.endDate),
                            y: .value("Room", lecture.location)
                        )
                        .foregroundStyle(.blue)
                        .annotation(position: .overlay) {
                            Text(lecture.name)
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                        }
                    }
                }
                .chartXScale(domain: dateRange)
                .chartLegend(.hidden)
                .if(true) { content -> AnyView in
                    guard #available(iOS 17, *) else {
                        return AnyView(
                            content
                                .frame(
                                    height: Double(buildingRooms.count) * 50.0
                                        + 10.0
                                )
                        )
                    }
                    return AnyView(
                        content
                            .chartScrollableAxes(.vertical)
                            .frame(height: 500)
                    )
                }
            } header: {
                AsyncStatusLight(status: _classroom.status)
            }
        }
        .asyncStatusOverlay(_classroom.status, showLight: false)
        .scrollContentBackground(.hidden)
        .refreshable {
            _classroom.triggerRefresh()
        }
        .navigationTitle("Classroom Status")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            _date = .now.add(day: 21)
        }
        .onChange(of: _date) { _ in
            _classroom.triggerRefresh()
        }
    }
}
