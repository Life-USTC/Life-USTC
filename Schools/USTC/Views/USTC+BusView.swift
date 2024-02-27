//
//  USTC+SchoolBusView.swift
//  Life@USTC
//
//  Created by Ode on 2023/9/14.
//

import SwiftUI

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

    var body: some View {
        @State var isExpanded = false
        VStack {
            ZStack(alignment: .top) {
                List {
                    ForEach(scheduleList) { schedule in
                        Group {
                            HStack {
                                // bold first and last, spacer in between
                                ForEach(schedule.route.indices, id: \.self) { index in
                                    Text(schedule.route[index].name)
                                        .fontWeight((index == 0 || index == schedule.route.count - 1) ? .bold : .light)
                                    if index != schedule.route.count - 1 {
                                        Spacer()
                                    }
                                }

                                Label("Expand", systemImage: "chevron.compact.right")
                                    .labelStyle(.iconOnly)
                                    .rotationEffect(.degrees(expandList.contains(schedule.route) ? 90.0 : 0.0))
                                    .foregroundColor(.accentColor)
                            }

                            if expandList.contains(schedule.route) {
                                ForEach(schedule.time.indices, id: \.self) { indice_i in
                                    HStack {
                                        ForEach(schedule.time[indice_i].indices, id: \.self) { index in
                                            Text(schedule.time[indice_i][index] ?? "--:--")
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundStyle(
                                                    (index == 0 || index == schedule.time[indice_i].count - 1)
                                                        ? .primary : .secondary
                                                )

                                            if index != schedule.time[indice_i].count - 1 {
                                                Spacer()
                                            }
                                        }
                                    }
                                    .background(
                                        Group {
                                            if indice_i == 0 {
                                                RoundedRectangle(cornerRadius: 5)
                                                    .fill(Color.blue.opacity(0.1))
                                                    .offset(y: 5)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .onTapGesture {
                            withAnimation {
                                if expandList.contains(schedule.route) {
                                    expandList.removeAll { $0 == schedule.route }
                                } else {
                                    expandList.append(schedule.route)
                                }
                            }
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
