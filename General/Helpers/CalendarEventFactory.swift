import CoreLocation
import EventKit
import SwiftData
import SwiftUI

extension EKEventStore {
    static var shared: EKEventStore = EKEventStore()
}

enum CalendarEventFactory {
    static func fromLecture(
        _ lecture: Lecture,
        in store: EKEventStore = .shared
    ) async throws -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = lecture.name
        event.startDate = lecture.startDate
        event.endDate = lecture.endDate

        try await applyLocation(lecture.location, to: event)

        return event
    }

    static func fromExam(
        _ exam: Exam,
        in store: EKEventStore = .shared
    ) async throws -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = exam.courseName + " " + exam.typeName
        event.notes = exam.detailText
        event.startDate = exam.startDate
        event.endDate = exam.endDate

        try await applyLocation(exam.detailLocation, to: event)

        return event
    }

    static func fromLectures(
        _ lectures: [Lecture],
        in store: EKEventStore = .shared
    ) async throws -> [EKEvent] {
        return try await lectures.asyncMap {
            try await fromLecture($0, in: store)
        }
    }

    static func fromExams(
        _ exams: [Exam],
        in store: EKEventStore = .shared
    ) async throws -> [EKEvent] {
        return try await exams.asyncMap {
            try await fromExam($0, in: store)
        }
    }

    private static func applyLocation(_ locationName: String, to event: EKEvent) async throws {
        let geoLocations: [GeoLocation] = try await [GeoLocation].refresh()

        let geoLocation = geoLocations.first {
            locationName.hasPrefix($0.name)
        }

        if let geoLocation {
            let ekLocation = EKStructuredLocation(title: locationName)
            ekLocation.geoLocation = CLLocation(
                latitude: geoLocation.latitude,
                longitude: geoLocation.longitude
            )
            event.structuredLocation = ekLocation
        } else {
            event.location = locationName
        }
    }
}

extension Sequence {
    func asyncMap<T>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var values = [T]()
        for element in self {
            try await values.append(transform(element))
        }
        return values
    }
}
