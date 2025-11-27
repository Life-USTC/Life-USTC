//
//  CurriculumListView.swift
//  Life@USTC
//
//  Created by TianKai Ma on 2024/3/11.
//

import Charts
import EventKit
import SwiftData
import SwiftUI

struct CurriculumListView: View {
    @Query(sort: \Semester.startDate, order: .forward) var semesters: [Semester]

    var dismissAction: (() -> Void)

    @ViewBuilder
    func section(for semester: Semester) -> some View {
        Section {
            ForEach(semester.coursesQuery, id: \.lessonCode) { course in
                VStack(alignment: .leading) {
                    HStack(alignment: .bottom) {
                        Text(course.name)
                        Text(String(course.credit))
                            .font(.system(.caption, weight: .semibold))
                            .foregroundColor(.secondary)

                        Spacer()
                    }

                    Text(course.lessonCode)
                        .font(.system(.caption2, weight: .light))
                        .foregroundColor(.secondary)

                    if let dateTimePlacePersonText = course.dateTimePlacePersonText,
                        !dateTimePlacePersonText.isEmpty
                    {
                        HStack {
                            Spacer()
                            Text(dateTimePlacePersonText)
                                .font(.system(.caption2, design: .monospaced, weight: .light))
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text(semester.name)

                Spacer()

                HStack(spacing: 0) {
                    Text(semester.startDate, style: .date)
                    Text("~")
                    Text(semester.endDate, style: .date)
                }
                .font(.system(.caption2, design: .monospaced, weight: .light))
            }
        } footer: {
        }
    }

    var body: some View {
        List {
            ForEach(semesters, id: \.id) { semester in
                section(for: semester)
            }
        }

        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismissAction()
                } label: {
                    Label("Done", systemImage: "xmark")
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        let eventStore = EKEventStore()
                        if #available(iOS 17.0, *) {
                            if EKEventStore.authorizationStatus(for: .event) != .fullAccess {
                                try? await eventStore.requestFullAccessToEvents()
                            }
                        } else {
                            _ = try? await eventStore.requestAccess(to: .event)
                        }

                        let calendarName = "Curriculum".localized
                        let calendars = eventStore.calendars(for: .event)
                            .filter { $0.title == calendarName.localized }
                        for calendar in calendars { try? eventStore.removeCalendar(calendar, commit: true) }

                        let calendar = EKCalendar(for: .event, eventStore: eventStore)
                        calendar.title = calendarName
                        calendar.cgColor = Color.accentColor.cgColor
                        calendar.source = eventStore.defaultCalendarForNewEvents?.source
                        try? eventStore.saveCalendar(calendar, commit: true)

                        let lectures = semesters.flatMap { $0.coursesQuery }.flatMap { $0.lecturesQuery }
                            .union()
                        for lecture in lectures {
                            let event = EKEvent(eventStore: eventStore)
                            event.title = lecture.name
                            event.startDate = lecture.startDate
                            event.endDate = lecture.endDate
                            event.location = lecture.location
                            event.calendar = calendar
                            try? eventStore.save(event, span: .thisEvent, commit: false)
                        }
                        try? eventStore.commit()
                    }
                } label: {
                    Label("Save to Calendar", systemImage: "calendar.badge.plus")
                }

                Button {
                    Task { await refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .navigationTitle("Curriculum")
        .task { await refresh() }
    }

    private func refresh() async {
        try? await CurriculumRepository.refresh()
    }
}
