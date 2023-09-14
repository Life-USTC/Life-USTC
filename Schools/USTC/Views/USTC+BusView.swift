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
                        Text(bus.from)
                        Spacer()
                        Text(bus.to)
                    }
                    HStack {
                        Text(bus.startTime.stripHMwithTimezone())
                        Spacer()
                        Text(calendar.date(byAdding: .minute, value: bus.timeTable.reduce(0, +), to: bus.startTime)! .stripHMwithTimezone())
                    }
                }
            }
        }
    }
}

#Preview {
    USTC_SchoolBusView()
}
