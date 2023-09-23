//
//  USTC+SchoolBusView.swift
//  Life@USTC
//
//  Created by Ode on 2023/9/14.
//

import SwiftUI

struct SingleBusView: View {
    var bus: Bus?
    let calendar = Calendar(identifier: .gregorian)
    var body: some View {
        VStack {
            HStack {
                if let bus {
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
                } else {
                    Text("No data")
                }
            }
        }
    }
}

struct BusListItem: Identifiable {
    var id = UUID()
    var bus: Bus?
    var subListItems: [BusListItem]?
}

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
    
    var topBusList: [BusListItem] {
        let showBuses = showPassBus ? filteredBuses : validBuses
        let GDBus = showBuses.filter() {
            return $0.from == "高新" && $0.to == "东区"
        }
        let DGBus = showBuses.filter() {
            return $0.to == "高新" && $0.from == "东区"
        }
        let DXBus = showBuses.filter() {
            return $0.from == "东区" && $0.to == "西区"
        }
        let XDBus = showBuses.filter() {
            return $0.from == "西区" && $0.to == "东区"
        }
        let DNBus = showBuses.filter() {
            return $0.from == "东区" && $0.to == "南区"
        }
        let NDBus = showBuses.filter() {
            return $0.from == "南区" && $0.to == "东区"
        }
        let XNBus = showBuses.filter() {
            return $0.from == "西区" && $0.to == "南区"
        }
        let NXBus = showBuses.filter() {
            return $0.from == "南区" && $0.to == "西区"
        }
        
        let subBusList1 = GDBus.suffix(from: min(1, GDBus.count)).map() { bus in BusListItem(bus: bus) }
        let subBusList2 = DGBus.suffix(from: min(1, DGBus.count)).map() { bus in BusListItem(bus: bus) }
        let subBusList3 = DXBus.suffix(from: min(1, DXBus.count)).map() { bus in BusListItem(bus: bus) }
        let subBusList4 = XDBus.suffix(from: min(1, XDBus.count)).map() { bus in BusListItem(bus: bus) }
        let subBusList5 = DNBus.suffix(from: min(1, DNBus.count)).map() { bus in BusListItem(bus: bus) }
        let subBusList6 = NDBus.suffix(from: min(1, NDBus.count)).map() { bus in BusListItem(bus: bus) }
        let subBusList7 = XNBus.suffix(from: min(1, XNBus.count)).map() { bus in BusListItem(bus: bus) }
        let subBusList8 = NXBus.suffix(from: min(1, NXBus.count)).map() { bus in BusListItem(bus: bus) }
        let topBusList = [
            BusListItem ( bus: GDBus.first, subListItems: subBusList1),
            BusListItem ( bus: DGBus.first, subListItems: subBusList2),
            BusListItem ( bus: DXBus.first, subListItems: subBusList3),
            BusListItem ( bus: XDBus.first, subListItems: subBusList4),
            BusListItem ( bus: DNBus.first, subListItems: subBusList5),
            BusListItem ( bus: NDBus.first, subListItems: subBusList6),
            BusListItem ( bus: XNBus.first, subListItems: subBusList7),
            BusListItem ( bus: NXBus.first, subListItems: subBusList8)
        ]
        return topBusList
    }

    var body: some View {
        @State var isExpanded = false
        VStack() {
            ZStack (alignment: .top){
                List(topBusList, children: \.subListItems){ busList in
                    SingleBusView(bus: busList.bus)
                }
                .padding(.top, 10)
                .listStyle(.insetGrouped)
                .refreshable {
                    _buses.triggerRefresh()
                }
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
                showPassBus = !showPassBus
            } label: {
                HStack {
                    Text("Show departed buses")
                        .foregroundColor(.primary)
                    Spacer()
                    showPassBus ?
                        Image(systemName: "checkmark.circle.fill")
                    :
                        Image(systemName: "circle")
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

#Preview{
    USTC_SchoolBusView()
}
