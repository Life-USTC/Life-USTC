import SwiftUI

struct ServerCampusWeatherView: View {
    @Environment(\.locale) private var locale
    @State private var location = ServerWeatherLocation.main
    @State private var snapshot: ServerWeatherSnapshot?
    @State private var error: String?
    @State private var isLoading = false

    var body: some View {
        List {
            Section {
                Picker("Campus", selection: $location) {
                    Text("Main Campus").tag(ServerWeatherLocation.main)
                    Text("Gaoxin Campus").tag(ServerWeatherLocation.gaoxin)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("weather_location")
            }
            if let error { Section { CampusErrorRow(message: error) { await load() } } }
            if isLoading { ProgressView("Loading weather…") }
            if let snapshot, snapshot.location.key == location {
                current(snapshot)
                if !snapshot.hourly.isEmpty {
                    Section("Hourly Forecast") {
                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 24) {
                                ForEach(snapshot.hourly) { hour in
                                    VStack(spacing: 8) {
                                        Text(campusClock(hour.at, locale: locale)).font(.caption)
                                        Text(temperature(hour.temperature)).font(.headline)
                                        if let condition = hour.condition { Text(condition.text).font(.caption) }
                                        if let chance = hour.precipitationProbability {
                                            Label("\(chance.formatted())%", systemImage: "drop.fill").font(.caption).foregroundStyle(.blue)
                                        }
                                        if let amount = hour.precipitationAmount {
                                            Text("\(amount.formatted()) mm").font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    .accessibilityElement(children: .combine)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                if !snapshot.daily.isEmpty {
                    Section("Daily Forecast") {
                        ForEach(snapshot.daily) { day in
                            HStack {
                                Text(day.date).font(.subheadline)
                                Spacer()
                                if let condition = day.condition { Text(condition.text).font(.caption).foregroundStyle(.secondary) }
                                Text("\(temperature(day.temperatureLow)) / \(temperature(day.temperatureHigh))").monospacedDigit()
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                Section("Weather Alerts") {
                    if snapshot.alerts.isEmpty { Text("No active weather alerts.").foregroundStyle(.secondary) }
                    ForEach(Array(snapshot.alerts.enumerated()), id: \.offset) { _, alert in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(alert.title).font(.headline)
                            if let level = alert.level { Text(level).foregroundStyle(.orange) }
                            if let content = alert.content { Text(content).font(.subheadline) }
                            if let issuedAt = alert.issuedAt { Text(issuedAt, style: .date).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
                Section {
                    Text(String(format: "Retrieved at %@ (Shanghai)".localized, campusDateTime(snapshot.fetchedAt, locale: locale)))
                    if !snapshot.providers.isEmpty {
                        Text(String(format: "Weather providers: %@".localized, snapshot.providers.map(providerName).joined(separator: ", ")))
                    }
                    Text("Forecast times use Shanghai time.")
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Campus Weather")
        .environment(\.timeZone, YoungCalendarDate.shanghai)
        .task(id: location) { await load() }
        .refreshable { await load() }
    }

    private func current(_ snapshot: ServerWeatherSnapshot) -> some View {
        Section("Current Weather") {
            VStack(alignment: .leading, spacing: 8) {
                Text(temperature(snapshot.current.temperature)).font(.system(size: 58, weight: .light)).monospacedDigit()
                Text(snapshot.current.condition.text).font(.title3)
                if let observedAt = snapshot.current.observedAt {
                    Text(String(format: "Observed at %@ (Shanghai)".localized, campusDateTime(observedAt, locale: locale)))
                        .font(.caption).foregroundStyle(.secondary)
                } else { Text("Observation time unavailable").font(.caption).foregroundStyle(.secondary) }
                if let source = snapshot.current.source {
                    Text(String(format: "Current weather source: %@".localized, providerName(source))).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            if let feelsLike = snapshot.current.feelsLike { LabeledContent("Feels Like", value: temperature(feelsLike)) }
            if let humidity = snapshot.current.humidity { LabeledContent("Humidity", value: "\(humidity.formatted())%") }
            if let direction = snapshot.current.windDirection, let force = snapshot.current.windSpeed {
                LabeledContent("Wind", value: String(format: "%@ wind, force %@".localized, direction, force.formatted()))
            }
        }
    }

    private func temperature(_ value: Double?) -> String {
        value.map { "\($0.formatted(.number.precision(.fractionLength(0))))°" } ?? "—"
    }

    private func providerName(_ source: String) -> String { source == "amap" ? "AMap" : "Open-Meteo" }

    private func load() async {
        let requestedLocation = location
        isLoading = true
        error = nil
        defer { if requestedLocation == location { isLoading = false } }
        do {
            let value = try await ServerClient.shared.fetchWeather(location: requestedLocation)
            guard requestedLocation == location, !Task.isCancelled else { return }
            snapshot = value
        } catch is CancellationError { return }
        catch { if requestedLocation == location, !Task.isCancelled { self.error = error.localizedDescription } }
    }
}

func campusDateTime(_ date: Date, locale: Locale) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = YoungCalendarDate.shanghai
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
}
