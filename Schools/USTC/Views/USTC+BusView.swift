//
//  USTC+SchoolBusView.swift
//  Life@USTC
//
//  Created by Ode on 2023/9/14.
//

import SwiftUI

extension String {
    fileprivate var hhmm_value: Int {
        let components = self.split(separator: ":")
        return Int(components[0])! * 60 + Int(components[1])!
    }
}

extension [[String?]] {
    fileprivate func filterBefore(_ date: Date) -> [[String]] {
        let hhmm = date.HHMM
        return self.filter { $0[0] != nil }.filter {
            let time = $0[0]!.hhmm_value
            return time >= hhmm
        }.map { $0.compactMap { $0 } }
    }
    
    fileprivate func nextTime(after date: Date) -> String? {
        let hhmm = date.HHMM
        return self.filter { $0[0] != nil }.map { $0[0]! }.filter { $0.hhmm_value >= hhmm }.first
    }
    
    fileprivate func nextTimes(after date: Date) -> [String?]? {
        let hhmm = date.HHMM
        return self.filter { $0[0] != nil }.filter { $0[0]!.hhmm_value >= hhmm }.first
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
    
//    var scheduleList: [USTCRouteSchedule] {
//        if showPassBus {
//            return _scheduleList
//        } else {
//            return _scheduleList.map { schedule in
//                let time = schedule.time.filterBefore(Date()) // TODO: REMOVE THIS F*CK
//                return USTCRouteSchedule(route: schedule.route, time: time)
//            }
//        }
//    }
    
    @ViewBuilder func makeTopView(_ schedule: USTCRouteSchedule) -> some View {
        HStack {
            VStack {
                HStack {
                    // bold first and last, spacer in between
                    ForEach(schedule.route.indices, id: \.self) { index in
                        Text(schedule.route[index].name)
                            .fontWeight((index == 0 || index == schedule.route.count - 1) ? .bold : .light)
                        if index != schedule.route.count - 1 {
                            Spacer()
                        }
                    }
                }
                
                if let nextTimes = schedule.time.nextTimes(after: Date()) {
                    HStack {
                        ForEach(nextTimes.indices, id: \.self) { index in
                            Text(nextTimes[index] ?? "--:--")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(
                                    (index == 0 || index == nextTimes.count - 1)
                                    ? Color.accentColor : Color.secondary
                                )
                            if index != nextTimes.count - 1 {
                                Spacer()
                            }
                        }
                    }
                } else {
                    Text("No more bus today")
                        .foregroundStyle(.secondary)
                        .font(.system(.caption, design: .monospaced))
                }
            }
            
            Label("Expand", systemImage: "chevron.compact.right")
                .labelStyle(.iconOnly)
                .rotationEffect(.degrees(expandList.contains(schedule.route) ? 90.0 : 0.0))
                .foregroundColor(.accentColor)
        }
    }
    
    @ViewBuilder func makeExpanedView(_ schedule: USTCRouteSchedule) -> some View {
        let time = showPassBus ? schedule.time : schedule.time.filterBefore(Date())
        VStack {
            ForEach(time.indices, id: \.self) { indice_i in
                HStack {
                    ForEach(time[indice_i].indices, id: \.self) { index in
                        Text(time[indice_i][index] ?? "--:--")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(
                                (index == 0 || index == time[indice_i].count - 1)
                                ? .primary : .secondary
                            )
                        
                        if index != time[indice_i].count - 1 {
                            Spacer()
                        }
                    }
                }
                .background(
                    Group {
                        if time[indice_i][0] == schedule.time.nextTime(after: Date()) {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.blue.opacity(0.1))
                        }
                    }
                )
            }
        }
    }

    var body: some View {
        @State var isExpanded = false
        VStack {
            ZStack(alignment: .top) {
                List {
                    ForEach(scheduleList) { schedule in
                        makeTopView(schedule)
                            .onTapGesture {
                                withAnimation {
                                    if expandList.contains(schedule.route) {
                                        expandList.removeAll { $0 == schedule.route }
                                    } else {
                                        expandList.append(schedule.route)
                                    }
                                }
                            }

                        if expandList.contains(schedule.route) {
                            makeExpanedView(schedule)
                        }
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
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        Color.blue
                            .opacity(0.1)
                    )
            }
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    USTC_SchoolBusView()
}
