import MapKit
import SwiftUI

struct ServerBusPlannerView: View {
    @Environment(\.locale) private var locale
    @Bindable private var account = ServerAccountStore.shared
    @State private var model = ServerBusPlannerModel()

    var body: some View {
        List {
            if let error = model.error { Section { CampusErrorRow(message: error) { await model.load() } } }
            if model.isLoading && model.timetable == nil { ProgressView("Loading bus timetable…") }
            if let timetable = model.timetable {
                Section("Next Departure") {
                    if model.isLoadingDepartures { ProgressView() }
                    if let next = model.next {
                        let upcoming = Array(next.departures.filter { $0.status == "upcoming" }.prefix(3))
                        if let first = upcoming.first {
                            departureRow(first, prominent: true)
                            ForEach(Array(upcoming.dropFirst())) { departure in departureRow(departure, prominent: false) }
                        } else {
                            Text(next.message ?? "No upcoming departures".localized).foregroundStyle(.secondary)
                            if let following = next.nextAvailableDeparture {
                                Text("Next Available Service").font(.caption).foregroundStyle(.secondary)
                                departureRow(following, prominent: false)
                                Text(dayTitle(following.dayType.rawValue)).font(.caption)
                            }
                        }
                        Text(String(format: "Updated at %@ (Shanghai)".localized, campusClock(next.atTime, locale: locale)))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let error = model.departureError {
                        CampusErrorRow(message: error) { await model.refreshDepartures(locale: campusAPILocale(locale)) }
                    }
                    if model.origin == model.destination { Text("Choose different departure and arrival campuses.").foregroundStyle(.secondary) }
                }
                Section("Route") {
                    Picker("From", selection: Binding(get: { model.origin }, set: { model.selectOrigin($0) })) {
                        Text("Select campus").tag(nil as Int?)
                        ForEach(timetable.campuses) { campus in Text(campusName(campus, locale: locale)).tag(Optional(campus.id)) }
                    }
                    .accessibilityIdentifier("bus_origin")
                    Picker("To", selection: Binding(get: { model.destination }, set: { model.selectDestination($0) })) {
                        Text("Select campus").tag(nil as Int?)
                        ForEach(timetable.campuses) { campus in Text(campusName(campus, locale: locale)).tag(Optional(campus.id)) }
                    }
                    .accessibilityIdentifier("bus_destination")
                    Button { model.reverse() } label: { Label("Reverse Direction", systemImage: "arrow.up.arrow.down") }
                        .accessibilityIdentifier("bus_reverse")
                    Picker("Day", selection: $model.dayType) {
                        ForEach(["auto", "weekday", "saturday", "sunday"], id: \.self) { day in Text(dayTitle(day)).tag(day) }
                    }
                    Toggle("Show Departed Trips", isOn: Binding(get: { model.showDeparted }, set: { model.setShowDeparted($0) }))
                    if account.isAuthenticated {
                        Button("Save Bus Preferences") { Task { await model.savePreference() } }
                            .disabled(!model.canSavePreference)
                            .accessibilityIdentifier("bus_save_preferences")
                        if model.isSavingPreference { ProgressView() }
                        if let error = model.preferenceError {
                            CampusErrorRow(message: error) {
                                if model.canSavePreference { await model.savePreference() }
                                else { await model.loadPreference() }
                            }
                        }
                    }
                    NavigationLink { ServerBusMapView(timetable: timetable) } label: { Label("Shuttle Map", systemImage: "map") }
                }
                .disabled(model.isSavingPreference)
                Section {
                    Picker("Timetable Version", selection: $model.versionKey) {
                        Text("Current timetable").tag(nil as String?)
                        ForEach(timetable.availableVersions) { version in
                            Text(versionLabel(version)).tag(Optional(version.key))
                        }
                    }
                    if let notice = timetable.notice {
                        if let message = notice.message { Text(message).font(.caption) }
                        if let rawURL = notice.url, let url = URL(string: rawURL) { Link("Timetable Notice", destination: url) }
                    }
                }
                if !model.isLoading {
                    ForEach(model.orderedRoutes) { route in
                        Section {
                            let trips = model.trips(for: route.id)
                            if trips.isEmpty { Text("No trips for this selection.").foregroundStyle(.secondary) }
                            ForEach(trips) { trip in
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(route.stops.sorted { $0.stopOrder < $1.stopOrder }, id: \.stopOrder) { stop in
                                        HStack {
                                            Text(campusName(stop.campus, locale: locale))
                                            Spacer()
                                            Text(stopClock(campusID: stop.campus.id, trip: trip)).monospacedDigit()
                                        }
                                        .font(stop.campus.id == model.origin || stop.campus.id == model.destination ? .body : .caption)
                                        .foregroundStyle(stop.campus.id == model.origin || stop.campus.id == model.destination ? .primary : .secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        } header: {
                            Text(route.descriptionPrimary)
                        }
                    }
                    Section {
                        Text("~ marks a timetable estimate between two known stop times. Unknown times cannot identify a next departure.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Bus Timetable")
        .task(id: "\(account.sessionRevision):\(model.versionKey ?? "current")") { await model.load() }
        .task(id: "\(model.queryKey):\(locale.identifier)") {
            while !Task.isCancelled {
                await model.refreshDepartures(locale: campusAPILocale(locale))
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
        .refreshable {
            await model.load()
            await model.refreshDepartures(locale: campusAPILocale(locale))
        }
    }

    private func departureRow(_ departure: ServerBusDeparture, prominent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text((departure.departureEstimated ? "~" : "") + (departure.departureTime ?? "Unknown time".localized))
                    .font(prominent ? .largeTitle.bold() : .headline)
                    .foregroundStyle(prominent ? Color.accentColor : Color.primary)
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                Text((departure.arrivalEstimated ? "~" : "") + (departure.arrivalTime ?? "Unknown time".localized))
                    .font(prominent ? .title2 : .body)
            }
            .monospacedDigit()
            if let origin = departure.originCampus, let destination = departure.destinationCampus {
                Text("\(campusName(origin, locale: locale)) → \(campusName(destination, locale: locale))")
            }
            Text(departure.route.descriptionPrimary).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func stopClock(campusID: Int, trip: ServerBusTrip) -> String {
        guard let clock = ServerBusStopClock.at(campusID: campusID, trip: trip) else { return "Unknown time".localized }
        return (clock.estimated ? "~" : "") + clock.text
    }

    private func dayTitle(_ day: String) -> String {
        switch day {
        case "weekday": "Weekday".localized
        case "saturday": "Saturday".localized
        case "sunday": "Sunday".localized
        default: "Today".localized
        }
    }

    private func versionLabel(_ version: ServerCampusBusTimetable.Version) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateStyle = .medium
        let date = formatter.string(from: version.effectiveFrom ?? version.importedAt)
        return String(format: "Timetable from %@".localized, date)
    }
}

struct ServerBusMapView: View {
    let timetable: ServerCampusBusTimetable
    @Environment(\.locale) private var locale

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let trips = ServerBusActiveTrip.trips(timetable.trips, at: timeline.date)
            Map {
                ForEach(timetable.routes) { route in
                    MapPolyline(coordinates: route.stops.sorted { $0.stopOrder < $1.stopOrder }.map {
                        CLLocationCoordinate2D(latitude: $0.campus.latitude, longitude: $0.campus.longitude)
                    })
                    .stroke(Color.accentColor, lineWidth: 3)
                }
                ForEach(timetable.campuses) { campus in
                    Marker(campusName(campus, locale: locale), coordinate: CLLocationCoordinate2D(latitude: campus.latitude, longitude: campus.longitude))
                }
                ForEach(trips) { trip in
                    if let route = timetable.routes.first(where: { $0.id == trip.routeID }),
                       let coordinate = trip.coordinate(in: route) {
                        Annotation(trip.status == .enRoute ? "Estimated bus location".localized : "Departing within 60 minutes".localized,
                                   coordinate: coordinate) {
                            Image(systemName: "bus.fill")
                                .padding(8)
                                .foregroundStyle(.white)
                                .background(trip.status == .enRoute ? Color.accentColor : .orange, in: Circle())
                                .symbolEffect(.pulse, options: .repeating)
                        }
                    }
                }
            }
            .mapControls { MapCompass(); MapScaleView() }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bus positions are timetable estimates, not GPS locations.").font(.caption)
                    Text(String(format: "Updated at %@ (Shanghai)".localized, campusClock(timeline.date, locale: locale)))
                        .font(.caption).foregroundStyle(Color.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.regularMaterial)
            }
            .navigationTitle("Shuttle Map")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
