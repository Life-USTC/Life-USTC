import CoreLocation
import EventKit
import SwiftData
import SwiftUI

struct CalendarEventFactory {
    static let shared = CalendarEventFactory()

    @Query var geoLocationData: [GeoLocationData]

    func fromLecture(
        _ lecture: Lecture,
        in store: EKEventStore = EKEventStore()
    ) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = lecture.name
        event.startDate = lecture.startDate
        event.endDate = lecture.endDate

        applyLocation(lecture.location, to: event)

        return event
    }

    func fromExam(
        _ exam: Exam,
        in store: EKEventStore = EKEventStore()
    ) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = exam.courseName + " " + exam.typeName
        event.notes = exam.detailText
        event.startDate = exam.startDate
        event.endDate = exam.endDate

        applyLocation(exam.detailLocation, to: event)

        return event
    }

    func fromLectures(
        _ lectures: [Lecture],
        in store: EKEventStore = EKEventStore()
    ) -> [EKEvent] {
        return lectures.map {
            fromLecture($0, in: store)
        }
    }

    func fromExams(
        _ exams: [Exam],
        in store: EKEventStore = EKEventStore()
    ) -> [EKEvent] {
        return exams.map {
            fromExam($0, in: store)
        }
    }

    private func applyLocation(_ locationName: String, to event: EKEvent) {
        let location = geoLocationData.first {
            locationName.hasPrefix($0.name)
        }

        if let location {
            let ekLocation = EKStructuredLocation(title: locationName)
            ekLocation.geoLocation = CLLocation(
                latitude: location.latitude,
                longitude: location.longitude
            )
            event.structuredLocation = ekLocation
        } else {
            event.location = locationName
        }
    }
}
