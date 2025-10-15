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
        return self[0] == nil ? false : self[0]!.hhmm_value < date.HHMM
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
    @AppStorage("ustcbusview_pineed_routes_id_list") var pinnedRoutes: [Int] = []
    @State var selection: Selection = {
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        return dayOfWeek == 1 || dayOfWeek == 7 ? .weekend : .weekday
    }()

    var _scheduleList: [USTCRouteSchedule] {
        switch selection {
        case .weekday:
            return data.weekday_routes
        case .weekend:
            return data.weekend_routes
        }
    }

    var scheduleList: [USTCRouteSchedule] {
        _scheduleList.filter { pinnedRoutes.contains($0.id) } + _scheduleList.filter { !pinnedRoutes.contains($0.id) }
    }

    @ViewBuilder func makeTopView(_ schedule: USTCRouteSchedule) -> some View {
        HStack(spacing: 0) {
            Group {
                if pinnedRoutes.contains(schedule.id) {
                    Image(systemName: "pin.fill")
                        .rotationEffect(.degrees(-45))
                        .foregroundColor(.accentColor)
                        .font(.caption)
                } else {
                    Spacer()
                }
            }
            .frame(width: 2)

            if let nextTimes = schedule.time.filter({ !$0.passed() }).first {
                HStack {
                    ForEach(schedule.route.campuses.indices, id: \.self) { index in
                        VStack(alignment: .center) {
                            Text(schedule.route.campuses[index].name)
                                .foregroundColor(
                                    (index == 0 || index == schedule.route.campuses.count - 1) ? .primary : .secondary
                                )
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
                        ForEach(schedule.route.campuses.indices, id: \.self) { index in
                            Text(schedule.route.campuses[index].name)
                                .foregroundColor(
                                    (index == 0 || index == schedule.route.campuses.count - 1) && showPassBus
                                        ? .primary : .secondary
                                )
                                .frame(width: 60)
                            if index != schedule.route.campuses.count - 1 {
                                Spacer()
                            }
                            if index == 0 && schedule.route.campuses.count == 2 {
                                Rectangle()
                                    .frame(width: 40, height: 1)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }

                    Text("No more bus today")
                        //                        .padding(.top, schedule.route.campuses.count == 2 ? 0 : 2)
                        .foregroundStyle(.secondary)
                        .font(.system(.caption2, design: .monospaced))
                }
            }
        }
    }

    @ViewBuilder func makeExpanedView(_ time: [[String?]]) -> some View {
        VStack {
            ForEach(time.indices, id: \.self) { indice_i in
                HStack {
                    ForEach(time[indice_i].indices, id: \.self) { index in
                        Text(time[indice_i][index] ?? "即停")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(
                                (time[indice_i] == time.filter({ !$0.passed() }).first)
                                    ? Color.accentColor
                                    : ((index == 0 || index == time[indice_i].count - 1) && !time[indice_i].passed()
                                        ? Color.primary : Color.secondary)
                            )
                            .fontWeight(
                                time[indice_i] == time.filter({ !$0.passed() }).first ? .heavy : .regular
                            )

                        if index != time[indice_i].count - 1 {
                            Spacer()
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    var body: some View {
        @State var isExpanded = false
        ZStack(alignment: .bottom) {
            ZStack(alignment: .top) {
                List {
                    Section {
                        ForEach(scheduleList) { schedule in
                            ZStack {
                                Color.clear
                                    .contentShape(Rectangle())
                                makeTopView(schedule)
                            }
                            .onTapGesture {
                                if expandList.contains(schedule.route) {
                                    expandList.removeAll { $0 == schedule.route }
                                } else {
                                    expandList.append(schedule.route)
                                }
                            }
                            .onLongPressGesture(minimumDuration: 0.2) {
                                if pinnedRoutes.contains(schedule.id) {
                                    pinnedRoutes.removeAll { $0 == schedule.id }
                                } else {
                                    pinnedRoutes.append(schedule.id)
                                }
                            }

                            let time = (showPassBus ? schedule.time : schedule.time.filterAfter())
                            if expandList.contains(schedule.route) && !time.isEmpty {
                                makeExpanedView(time)
                            }
                        }
                    } header: {
                        AsyncStatusLight(status: _data.status)
                    } footer: {
                        VStack {
                            Text("Tap on a route to expand, Long press to pin/unpin")
                            Spacer(minLength: 80)
                        }
                    }
                }
                .padding(.top, 10)
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

            VStack {
                Button {
                    showPassBus.toggle()
                } label: {
                    HStack {
                        Text("Show departed buses")
                            .foregroundColor(.primary)
                        Spacer()

                        Image(systemName: showPassBus ? "checkmark.circle.fill" : "circle")
                    }
                }
                .padding([.top, .horizontal])

                if let message = data.message?.message, let _url = data.message?.url, let url = URL(string: _url) {
                    Link(message, destination: url)
                        .font(.caption2)
                        .padding(.vertical, 4)
                }
            }
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color("BackgroundWhite"))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.blue.opacity(0.1))
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
