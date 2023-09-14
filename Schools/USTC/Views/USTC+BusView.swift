//
//  USTC+SchoolBusView.swift
//  Life@USTC
//
//  Created by Ode on 2023/9/14.
//

import SwiftUI

struct USTC_SchoolBusView: View {
    @ManagedData(.bus) var buses: [Bus]
    @AppStorage("ustcBusSelectedDate") var _date: Date = .now
    var body: some View {
        let calendar = Calendar(identifier: .gregorian)
        List {
            ForEach(buses) { bus in
                VStack {
                    HStack {
                        VStack (alignment: .leading){
                            HStack (alignment: .bottom){
                                Text(bus.from)
                                    .fontWeight(.heavy)
                                if (bus.from == "高新" && bus.to == "东区") {
                                    Text("先研院")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                } else if (bus.from == "东区" && bus.to == "高新") {
                                    Text("西区")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                    
                            }
                            HStack (alignment: .top){
                                Text(bus.startTime.stripHMwithTimezone())
                                    .font(.caption)
                                if (bus.from == "高新" && bus.to == "东区") {
                                    Text(calendar.date(byAdding: .minute, value: 5, to: bus.startTime)! .stripHMwithTimezone())
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                } else if (bus.from == "东区" && bus.to == "高新") {
                                    Text(calendar.date(byAdding: .minute, value: 10, to: bus.startTime)! .stripHMwithTimezone())
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                        }
                        Spacer()
                        Text("      ")
                            .foregroundColor(.gray)
                        Spacer()
                        VStack (alignment: .trailing){
                            HStack (alignment: .bottom){
                                Spacer()
                                if (bus.from == "高新" && bus.to == "东区") {
                                    Text("西区")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                } else if (bus.from == "东区" && bus.to == "高新") {
                                    Text("先研院")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Text(bus.to)
                                    .fontWeight(.heavy)
                            }
                            HStack {
                                Spacer()
                                Text("随停")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(calendar.date(byAdding: .minute, value: bus.timeTable.reduce(0, +), to: bus.startTime)! .stripHMwithTimezone())
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .refreshable {
            _buses.triggerRefresh()
        }
        .navigationTitle("Bus Timetable")
    }
}

#Preview {
    USTC_SchoolBusView()
}
