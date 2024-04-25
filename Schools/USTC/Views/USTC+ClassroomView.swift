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
    enum Selection: String, CaseIterable {
        case morning
        case afternoon
        case night
    }

    @ManagedData(.classroom) var classroom: [String: [Lecture]]
    @AppStorage("ustcClassroomSelectedBuilding") var selectedBuilding: String = "5"
    @State var _date: Date = .now
    @State var selection: Selection = {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 0 ..< 12: return .morning
        case 14 ..< 19: return .afternoon
        default: return .night
        }
    }()

    @AppStorage("ustcClassroomUseBrowser") var useBrowser: Bool = true

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
        ustcBuildingNames.first { $0.0 == selectedBuilding }?.1 ?? "Unknown"
    }

    var buildingRooms: [String] {
        ustcBuildingRooms[selectedBuilding] ?? []
    }

    var lectures: [Lecture] {
        classroom[selectedBuilding] ?? []
    }

    var customView: some View {
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
                        ForEach(Array(ustcBuildingNames), id: \.0.self) { building in
                            Button {
                                selectedBuilding = building.0
                            } label: {
                                Text(building.1)
                            }
                        }
                    } label: {
                        Text(buildingName)
                    }
                }

                Picker(
                    "Time",
                    selection: $selection
                ) {
                    ForEach(Selection.allCases, id: \.self) {
                        Text($0.rawValue.capitalized)
                    }
                }
                .pickerStyle(.segmented)

                Chart {
                    ForEach(buildingRooms, id: \.self) { room in
                        BarMark(
                            xStart: .value("Start time", date),
                            xEnd: .value("End time", date.add(day: 1)),
                            y: .value("Room", room),
                            height: .ratio(0.8)
                        )
                        .foregroundStyle(.clear)
                    }

                    ForEach(lectures) { lecture in
                        BarMark(
                            xStart: .value("Start time", lecture.startDate),
                            xEnd: .value("End time", lecture.endDate),
                            y: .value("Room", lecture.location),
                            height: .ratio(0.8)
                        )
                        .foregroundStyle(.blue.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .annotation(position: .overlay) {
                            Text(lecture.name)
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                        }
                    }
                }
                .chartXScale(domain: dateRange)
                .chartXAxis {
                    AxisMarks(
                        preset: .automatic,
                        position: .top,
                        values: .stride(by: .hour, count: 1)
                    ) {
                        AxisValueLabel(format: .dateTime.hour())
                        AxisGridLine()
                    }
                    AxisMarks(values: [Date()]) {
                        AxisGridLine()
                            .foregroundStyle(.red)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: buildingRooms)
                }
                .chartLegend(.hidden)
                .frame(height: Double(buildingRooms.count) * 50.0 + 10.0)
            } header: {
                AsyncStatusLight(status: _classroom.status)
            }
        }
        .asyncStatusOverlay(_classroom.status)
        .scrollContentBackground(.hidden)
        .refreshable {
            _classroom.triggerRefresh()
        }
        .onChange(of: _date) { _ in
            _classroom.triggerRefresh()
        }
    }

    var body: some View {
        Group {
            if useBrowser {
                SwiftUIWebView(url: URL(string: "https://catalog.ustc.edu.cn/query/classroom")!)
            } else {
                customView
            }
        }
        .navigationTitle("Classroom Status")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    useBrowser.toggle()
                } label: {
                    Image(systemName: useBrowser ? "doc.append" : "safari")
                }
            }
        }
    }
}
