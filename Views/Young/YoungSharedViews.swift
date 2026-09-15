//
//  YoungSharedViews.swift
//  Life@USTC
//
//  Shared views and formatting for the Second Classroom feature.
//

import Foundation
import SwiftUI

struct YoungErrorView: View {
    let error: String
    let retry: () -> Void
    let reauthorize: Bool

    init(error: String, retry: @escaping () -> Void, reauthorize: Bool = false) {
        self.error = error
        self.retry = retry
        self.reauthorize = reauthorize
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.orange)
            Text("Unable to load")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
            if reauthorize {
                YoungReauthorizeButton()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding()
    }
}

struct YoungReauthorizeButton: View {
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 6) {
            Button("Sign in again to authorize") {
                Task {
                    isLoading = true
                    error = nil
                    ServerAuth.shared.logout()
                    do {
                        try await ServerAuth.shared.login()
                    } catch {
                        self.error = error.localizedDescription
                    }
                    isLoading = false
                }
            }
            .disabled(isLoading)
            if isLoading { ProgressView() }
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

struct YoungLoginRequiredView: View {
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.lock")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text("Sign in to use workspace features")
                .font(.headline)
            Text("Subscriptions, your personal calendar, and notifications are linked to your Life@USTC account.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task {
                    isLoading = true
                    error = nil
                    do {
                        try await ServerAuth.shared.login()
                    } catch {
                        self.error = error.localizedDescription
                    }
                    isLoading = false
                }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 280)
    }
}

enum YoungFormatting {
    static func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: key.localized, arguments: arguments)
    }

    static func dateRange(_ start: Date?, _ end: Date?, includeYear: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.calendar = YoungCalendarDate.calendar
        formatter.timeZone = YoungCalendarDate.shanghai
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = includeYear ? "yyyy-MM-dd HH:mm" : "M月d日 HH:mm"
        switch (start, end) {
        case let (start?, end?):
            return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
        case let (start?, nil):
            return formatter.string(from: start)
        case let (nil, end?):
            return localizedFormat("Ends %@", formatter.string(from: end))
        case (nil, nil):
            return "Time unavailable".localized
        }
    }

    static func rangeTitle(for mode: YoungCalendarDisplayMode, date: Date) -> String {
        let range = YoungCalendarDate.range(for: mode, date: date)
        return range.from == range.to ? range.from : "\(range.from) – \(range.to)"
    }

    static func dayTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = YoungCalendarDate.calendar
        formatter.timeZone = YoungCalendarDate.shanghai
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: date)
    }

    static func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = YoungCalendarDate.calendar
        formatter.timeZone = YoungCalendarDate.shanghai
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    static func countText(_ count: Int, key: String) -> String {
        localizedFormat(key, count)
    }
}

struct YoungSourceFreshnessView: View {
    let source: ServerYoungCatalogSource

    var body: some View {
        HStack(spacing: 6) {
            Label(source.status.localized, systemImage: source.status == "fresh" ? "checkmark.circle" : "clock")
            if let lastSyncedAt = source.lastSyncedAt {
                Text(lastSyncedAt, style: .relative)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

struct YoungEventRow: View {
    let event: ServerYoungEvent
    let basis: YoungEventTimeBasis

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.name)
                        .font(.headline)
                    if let organizer = event.organizer, !organizer.isEmpty {
                        Text(organizer)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if event.sourceMissing == true {
                    Text("Source missing")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if event.isActive {
                    Text("Open")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                }
            }

            let range = event.dateRange(for: basis)
            Text(YoungFormatting.dateRange(range.0, range.1))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if let category = event.category, !category.isEmpty {
                    Text(category)
                }
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct YoungCalendarDayAgenda: View {
    let date: Date
    let events: [ServerYoungEvent]
    let basis: YoungEventTimeBasis

    var body: some View {
        Section {
            if events.isEmpty {
                Text("No activities")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(events) { event in
                    NavigationLink {
                        YoungEventDetailView(youngId: event.youngId)
                    } label: {
                        YoungEventRow(event: event, basis: basis)
                    }
                }
            }
        } header: {
            Text(YoungFormatting.dayTitle(date))
        }
    }
}

extension ServerYoungEvent {
    func overlaps(day date: Date, basis: YoungEventTimeBasis) -> Bool {
        let calendar = YoungCalendarDate.calendar
        let dayStart = YoungCalendarDate.dayStart(date)
        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let range = dateRange(for: basis)
        guard let first = range.0 ?? range.1 else { return false }
        let start = range.0 ?? first
        let end = range.1 ?? first.addingTimeInterval(1)
        // Treat the end as exclusive. An event ending at midnight is shown on
        // the preceding day and does not leak into the following day's agenda.
        return start < nextDayStart && end > dayStart
    }
}
