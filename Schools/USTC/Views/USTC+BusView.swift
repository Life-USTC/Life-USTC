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

    @ManagedData(.bus) var buses: [Bus]
    @AppStorage("showBeforeBus") var showPassBus: Bool = true
    @State var selection: Selection = {
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        return dayOfWeek == 1 || dayOfWeek == 7 ? .weekend : .weekday
    }()

    var filteredBuses: [Bus] {
        switch selection {
        case .weekday:
            return buses.filter { $0.type == "weekday" || $0.type == "all" }
        case .weekend:
            return buses.filter { $0.type == "weekend" || $0.type == "all" }
        }
    }

    var validBuses: [Bus] {
        return filteredBuses.filter { $0.startTime.HHMM >= Date().HHMM }
    }

    var body: some View {
        let calendar = Calendar(identifier: .gregorian)
        VStack(spacing: 0) {
            VStack(spacing: 5) {
                Picker(
                    "Time",
                    selection: $selection
                ) {
                    ForEach(Selection.allCases, id: \.self) {
                        Text($0.rawValue.capitalized.localized)
                    }
                }
                .pickerStyle(.segmented)
                Button {
                    showPassBus = !showPassBus
                } label: {
                    HStack {
                        Text("Show departed buses")
                            .foregroundColor(.primary)
                        Spacer()
                        if showPassBus {
                            Image(systemName: "checkmark.circle.fill")
                        } else {
                            Image(systemName: "circle")
                        }
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
            }
            .padding(.horizontal, 20)
            List {
                ForEach(showPassBus ? filteredBuses : validBuses) { bus in
                    VStack {
                        HStack {
                            VStack(alignment: .leading) {
                                HStack(alignment: .bottom) {
                                    Text(bus.from)
                                        .fontWeight(.heavy)
                                    if bus.from == "高新" && bus.to == "东区" {
                                        Text("先研院")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    } else if bus.from == "东区" && bus.to == "高新" {
                                        Text("西区")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()

                                }
                                HStack(alignment: .top) {
                                    Text(bus.startTime.stripHMwithTimezone())
                                        .font(.caption)
                                    if bus.from == "高新" && bus.to == "东区" {
                                        Text(
                                            calendar.date(byAdding: .minute, value: 5, to: bus.startTime)!
                                                .stripHMwithTimezone()
                                        )
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    } else if bus.from == "东区" && bus.to == "高新" {
                                        Text(
                                            calendar.date(byAdding: .minute, value: 10, to: bus.startTime)!
                                                .stripHMwithTimezone()
                                        )
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    }
                                    Spacer()
                                }
                            }
                            Spacer()
                            VStack(alignment: .center) {
                                if bus.to == "西区" || bus.from == "西区" {
                                    Text("北区")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text("即停")
                                        .font(.caption)
                                        .foregroundColor(.gray)

                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                HStack(alignment: .bottom) {
                                    Spacer()
                                    if bus.from == "高新" && bus.to == "东区" {
                                        Text("西区")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    } else if bus.from == "东区" && bus.to == "高新" {
                                        Text("先研院")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Text(bus.to)
                                        .fontWeight(.heavy)
                                }
                                HStack {
                                    Spacer()
                                    if bus.from == "高新" || bus.to == "高新" {
                                        Text("即停")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Text(
                                        calendar.date(
                                            byAdding: .minute,
                                            value: bus.timeTable.reduce(0, +),
                                            to: bus.startTime
                                        )!
                                        .stripHMwithTimezone()
                                    )
                                    .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .refreshable {
                _buses.triggerRefresh()
            }
            .navigationTitle("Bus Timetable")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview{
    USTC_SchoolBusView()
}
