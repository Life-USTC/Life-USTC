//
//  USTC+SchoolBusView.swift
//  Life@USTC
//
//  Created by Ode on 2023/9/14.
//

import SwiftUI
import SwiftyJSON

extension String {
    fileprivate var hhmm_value: Int {
        let components = self.split(separator: ":")
        return Int(components[0])! * 60 + Int(components[1])!
    }
}

extension [String?] {
    fileprivate func passed(_ date: Date = Date()) -> Bool {
        return self[0] == nil ? false :self[0]!.hhmm_value < date.HHMM
    }
}

extension [[String?]] {
    fileprivate func filterAfter(_ date: Date = Date()) -> [[String?]] {
        return self.filter { !$0.passed(date) }
    }
}

struct USTC_SchoolBusView: View {
    enum Selection: String, CaseIterable {
        case weekday
        case weekend
    }

    @ManagedData(.ustcBus) var data: USTCBusData
    @AppStorage("showBeforeBus") var showPassBus: Bool = true
    @AppStorage("ustcbusview_schdule_expand_list") var expandList: [USTCRoute] = []
    @State var selection: Selection = {
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        return dayOfWeek == 1 || dayOfWeek == 7 ? .weekend : .weekday
    }()

    var scheduleList: [USTCRouteSchedule] {
        switch selection {
        case .weekday:
            return data.weekday_routes
        case .weekend:
            return data.weekend_routes
        }
    }
    
    @ViewBuilder func makeTopView(_ schedule: USTCRouteSchedule) -> some View {
        HStack(spacing: 0) {
            if let nextTimes = schedule.time.filter({ !$0.passed() }).first {
                HStack {
                    ForEach(schedule.route.indices, id: \.self) { index in
                        VStack(alignment: .center) {
                            Text(schedule.route[index].name)
                                .foregroundColor((index == 0 || index == schedule.route.count - 1) ? .primary : .secondary)
                                .frame(width: 60)
                            Text(nextTimes[index] ?? "即停")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    (index == 0 || index == nextTimes.count - 1)
                                    ? Color.accentColor : Color.secondary
                                )
                        }
                        if index != nextTimes.count - 1 {
                            Spacer()
                        }
                    }
                }
            } else {
                VStack {
                    HStack {
                        // bold first and last, spacer in between
                        ForEach(schedule.route.indices, id: \.self) { index in
                            Text(schedule.route[index].name)
                                .foregroundColor(.secondary)
                                .foregroundStyle(.secondary)
                                .frame(width: 60)
                            if index != schedule.route.count - 1 {
                                Spacer()
                            }
                        }
                    }
                    
                    Text("No more bus today")
                        .foregroundColor(.secondary)
                        .foregroundStyle(.secondary)
                        .font(.system(.caption, design: .monospaced))
                }
            }
        }
    }
    
    @ViewBuilder func makeExpanedView(_ schedule: USTCRouteSchedule) -> some View {
        let time = showPassBus ? schedule.time : schedule.time.filterAfter(Date())
        VStack {
            ForEach(time.indices, id: \.self) { indice_i in
                HStack {
                    HStack {
                        ForEach(time[indice_i].indices, id: \.self) { index in
                            Text(time[indice_i][index] ?? "即停")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(
                                    ((index == 0 || index == time[indice_i].count - 1) && !time[indice_i].passed())
                                    ? .primary : .secondary
                                )
                                .foregroundColor(
                                    time[indice_i].passed()
                                    ? .secondary : (time[indice_i] == schedule.time.filter({ !$0.passed() }).first ? Color.accentColor : .primary)
                                )
                                .fontWeight(
                                    time[indice_i] == schedule.time.filter({ !$0.passed() }).first ? .heavy : .regular
                                )
                            
                            if index != time[indice_i].count - 1 {
                                Spacer()
                            }
                        }
                    }
                    .foregroundStyle(.secondary)
                    /*
                    .background(
                        Group {
                            if time[indice_i] == schedule.time.filter({ !$0.passed() }).first {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.blue.opacity(0.1))
                            }
                        }
                    )
                    */
                }
            }
        }
        .padding(.horizontal, 12)
    }

    var body: some View {
        @State var isExpanded = false
        ZStack (alignment: .bottom) {
            ZStack(alignment: .top) {
                List {
                    Section {
                        ForEach(scheduleList) { schedule in
                            Button {
                                if expandList.contains(schedule.route) {
                                    expandList.removeAll { $0 == schedule.route }
                                } else {
                                    expandList.append(schedule.route)
                                }
                            } label: {
                                makeTopView(schedule)
//                                    .if(expandList.contains(schedule.route)) {
//                                        $0
//                                            .padding(10)
//                                            .background(
//                                                RoundedRectangle(cornerRadius: 6)
//                                                    .fill(Color.blue.opacity(0.06))
//                                            )
//                                    }
                            }
                            
                            if expandList.contains(schedule.route) {
                                makeExpanedView(schedule)
                            }
                        }
                    } header: {
                        AsyncStatusLight(status: _data.status)
                    } footer: {
                        Text("Tap on a route to expand")
                    }
                }
                .padding(.top, 10)
                .listStyle(.insetGrouped)
                .refreshable {
                    _data.triggerRefresh()
                }
                .asyncStatusOverlay(_data.status)
                .navigationTitle("Bus Timetable")
                .navigationBarTitleDisplayMode(.inline)

                Picker(
                    "Time",
                    selection: $selection
                ) {
                    ForEach(Selection.allCases, id: \.self) {
                        Text($0.rawValue.capitalized.localized)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .background(
                    Rectangle()
                        .fill(Color(.systemGroupedBackground))
                )
            }
            .padding(.bottom, 50)

            Button {
                showPassBus.toggle()
            } label: {
                HStack {
                    Text("Show departed buses")
                        .foregroundColor(.primary)
                    Spacer()
                    showPassBus
                        ? Image(systemName: "checkmark.circle.fill")
                        : Image(systemName: "circle")
                }
            }
            .padding()
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color("BackgroundWhite"))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.blue.opacity(0.2))
                }
            }
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    USTC_SchoolBusView()
}
