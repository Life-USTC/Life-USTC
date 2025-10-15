//
//  USTC+SchoolBusView.swift
//  Life@USTC
//
//  Created by Ode on 2023/9/14.
//

import SwiftUI
import SwiftyJSON

struct USTC_SchoolBusView: View {
    enum Selection: String, CaseIterable {
        case weekday
        case weekend
    }

    @ManagedData(.ustcBus) var data: USTCBusData
    @AppStorage("showBeforeBus") var showPassBus: Bool = true
    @AppStorage("ustcbusview_selected_routes") var selectedRouteIds: [Int] = []
    @State var selection: Selection = {
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        return dayOfWeek == 1 || dayOfWeek == 7 ? .weekend : .weekday
    }()

    @State private var showingSettings = false
    @State private var currentRouteIndex = 0

    var allScheduleList: [USTCRouteSchedule] {
        switch selection {
        case .weekday:
            return data.weekday_routes
        case .weekend:
            return data.weekend_routes
        }
    }

    var calculatedScheduleList: [USTCRouteSchedule] {
        var result = allScheduleList
        if !selectedRouteIds.isEmpty {
            result = allScheduleList.filter { selectedRouteIds.contains($0.route.id) }
        }

        for index in result.indices {
            result[index].time = result[index].time.filter { showPassBus || !$0.passed() }
        }
        return result
    }

    var availableRoutes: [USTCRoute] {
        return data.routes
    }

    // Time table for a specific route's schedule
    @ViewBuilder
    func makeTimeTableView(_ time: [[TimeString?]]) -> some View {
        VStack(spacing: 4) {
            // Determine next departure
            let nextDeparture = time.filter({ !$0.passed() }).first

            ForEach(time.indices, id: \.self) { rowIndex in
                HStack {
                    ForEach(time[rowIndex].indices, id: \.self) { colIndex in
                        Text(time[rowIndex][colIndex] ?? "即停".localized)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(
                                time[rowIndex] == nextDeparture
                                    ? .accentColor
                                    : ((colIndex == 0 || colIndex == time[rowIndex].count - 1)
                                        ? .primary
                                        : .secondary)
                            )
                            .fontWeight(time[rowIndex] == nextDeparture ? .bold : .regular)
                            .frame(minWidth: 60)

                        if colIndex != time[rowIndex].count - 1 {
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 2)
                .id(time[rowIndex].hashValue)
            }
        }
    }

    // Card view for a route - main component of the UI
    @ViewBuilder
    func RouteCardView(_ schedule: USTCRouteSchedule) -> some View {
        VStack {
            // Route header with campus names
            HStack {
                ForEach(schedule.route.campuses.indices, id: \.self) { index in
                    VStack(spacing: 0) {
                        Text(schedule.route.campuses[index].name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }

                    if index < schedule.route.campuses.count - 1 {
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                            .font(.headline)
                        Spacer()
                    }
                }
            }
            .padding(.bottom, 10)

            Divider()

            // Show next departure in large text if available
            if let nextTime = schedule.nextDeparture {
                Text("Next Departure")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                HStack {
                    ForEach(nextTime.indices, id: \.self) { index in
                        VStack {
                            Text(index == 0 ? "Depart" : index == nextTime.count - 1 ? "Arrive" : "")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(nextTime[index] ?? "即停".localized)
                                .font(.system(.title2, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(
                                    (index == 0 || index == nextTime.count - 1) ? .accentColor : .secondary
                                )
                        }

                        if index < nextTime.count - 1 {
                            Spacer()
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    if schedule.time.isEmpty {
                        Spacer()
                    }

                    Image(systemName: "bus.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("No more buses today")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    if schedule.time.isEmpty {
                        Button("Show Departed Buses") {
                            showPassBus = true
                        }
                        .font(.subheadline)
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                }
                .padding(.vertical)
            }

            if !schedule.time.isEmpty {
                Divider()
                Text("Schedule")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        makeTimeTableView(schedule.time)
                    }
                    .onAppear {
                        if let nextTime = schedule.nextDeparture {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation {
                                    proxy.scrollTo(nextTime.hashValue, anchor: .center)
                                }
                            }
                        }
                    }
                }
                .frame(height: 250)
            }
        }
        .padding(20)
        .frame(width: UIScreen.main.bounds.width - 40, height: 500)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))

                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            }
        )
    }

    // Settings sheet view
    @ViewBuilder
    func SettingsView() -> some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Schedule Type", selection: $selection) {
                        ForEach(Selection.allCases, id: \.self) {
                            Text($0.rawValue.capitalized.localized)
                        }
                    }
                    Toggle("Show Departed Buses", isOn: $showPassBus)
                } header: {
                    AsyncStatusLight(status: _data.status)
                } footer: {
                    if let message = data.message?.message, let _url = data.message?.url, let url = URL(string: _url) {
                        Link(message, destination: url)
                    }
                }

                Section {
                    Toggle(
                        isOn: Binding(
                            get: { selectedRouteIds.isEmpty },
                            set: {
                                if $0 {
                                    selectedRouteIds = []
                                    currentRouteIndex = 0
                                }
                            }
                        )
                    ) {
                        Text("Show All Routes")
                    }

                    ForEach(availableRoutes) { route in
                        let isSelected = selectedRouteIds.contains(route.id)
                        Button {
                            if isSelected {
                                selectedRouteIds.removeAll { $0 == route.id }
                            } else {
                                if selectedRouteIds.isEmpty {
                                    selectedRouteIds = [route.id]
                                } else {
                                    selectedRouteIds.append(route.id)
                                }
                            }
                            currentRouteIndex = 0
                        } label: {
                            HStack {
                                Text(route.description)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                } header: {
                    Text("Route Filter")
                }
            }
            .navigationTitle("Bus Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showingSettings = false
                    } label: {
                        Label("Done", systemImage: "xmark")
                    }
                }
            }
        }
    }

    // Page indicator view
    @ViewBuilder
    func PageIndicator(currentPage: Int, pageCount: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0 ..< pageCount, id: \.self) { page in
                Circle()
                    .fill(page == currentPage ? Color.accentColor : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 20)
    }

    var body: some View {
        VStack {
            HStack {
                Picker("", selection: $selection) {
                    ForEach(Selection.allCases, id: \.self) {
                        Text($0.rawValue.capitalized.localized)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .onChange(of: selection) { _ in
                    currentRouteIndex = 0  // Reset route index when changing schedule type
                }

                Spacer()

                Button {
                    showingSettings.toggle()
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 22))
                }
            }
            .padding(.horizontal)
            .padding(.bottom)

            // Main content - horizontal scrolling cards
            if calculatedScheduleList.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "bus.doubledecker")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("No Routes Available")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    Button("Configure Routes") {
                        showingSettings = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding(40)
            } else {
                TabView(selection: $currentRouteIndex) {
                    ForEach(Array(calculatedScheduleList.enumerated()), id: \.element.id) { index, schedule in
                        RouteCardView(schedule)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page indicator
                if calculatedScheduleList.count > 1 {
                    PageIndicator(currentPage: currentRouteIndex, pageCount: calculatedScheduleList.count)
                }
            }

            Spacer()
        }
        .padding(.vertical)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .navigationTitle("Bus Timetable")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .asyncStatusOverlay(_data.status)
        .onAppear {
            // Make sure currentRouteIndex is valid
            if !calculatedScheduleList.isEmpty && currentRouteIndex >= calculatedScheduleList.count {
                currentRouteIndex = 0
            }
        }
    }
}

#Preview {
    USTC_SchoolBusView()
}
