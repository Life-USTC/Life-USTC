//
//  EventKitExtension.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import EventKit
import EventKitUI
import UIKit

enum CustomError: Error {
    case calendarAccessDeniedOrRestricted
    case eventNotAddedToCalendar
    case eventAlreadyExistsInCalendar
}

typealias EventsCalendarManagerResponse = (_ result: Result<Bool, CustomError>) -> Void

class EventsCalendarManager: NSObject {
    static var main = EventsCalendarManager()
    var eventStore: EKEventStore!

    override init() {
        eventStore = EKEventStore()
    }

    /// Request access to the Calendar
    private func requestAccess(completion: @escaping EKEventStoreRequestAccessCompletionHandler) {
        eventStore.requestAccess(to: EKEntityType.event) { accessGranted, error in
            completion(accessGranted, error)
        }
    }

    /// Get Calendar auth status
    private func getAuthorizationStatus() -> EKAuthorizationStatus {
        return EKEventStore.authorizationStatus(for: EKEntityType.event)
    }

    /// Try to add an event to the calendar if authorized
    func addEventToCalendar(event: EKEvent, completion: @escaping EventsCalendarManagerResponse) {
        // Check Calendar permissions auth status
        switch getAuthorizationStatus() {
        case .authorized:
            addEvent(event: event, completion: { result in
                switch result {
                case .success:
                    completion(.success(true))
                case let .failure(error):
                    completion(.failure(error))
                }
            })
        case .notDetermined:
            // Auth is not determined
            // We should request access to the calendar
            requestAccess { accessGranted, error in
                if accessGranted {
                    self.addEvent(event: event, completion: { result in
                        switch result {
                        case .success:
                            completion(.success(true))
                        case let .failure(error):
                            completion(.failure(error))
                        }
                    })
                } else {
                    // Auth denied, we should display a popup
                    completion(.failure(.calendarAccessDeniedOrRestricted))
                }
            }
        case .denied, .restricted:
            // Auth denied or restricted, we should display a popup
            completion(.failure(.calendarAccessDeniedOrRestricted))
        @unknown default:
            completion(.failure(.calendarAccessDeniedOrRestricted))
        }
    }

    /// Generate an event which will be then added to the calendar
    private func generateEvent(event: EKEvent) -> EKEvent {
        let newEvent = EKEvent(eventStore: eventStore)
        newEvent.calendar = eventStore.defaultCalendarForNewEvents
        newEvent.title = event.title
        newEvent.startDate = event.startDate
        newEvent.endDate = event.endDate
        // Set default alarm minutes before event
        let alarm = EKAlarm(relativeOffset: -15 * 60)
        newEvent.addAlarm(alarm)
        return newEvent
    }

    /// Try to save an event to the calendar
    private func addEvent(event: EKEvent, completion: @escaping EventsCalendarManagerResponse) {
        let eventToAdd = generateEvent(event: event)
        if !eventAlreadyExists(event: eventToAdd) {
            do {
                try eventStore.save(eventToAdd, span: .thisEvent)
            } catch {
                // Error while trying to create event in calendar
                completion(.failure(.eventNotAddedToCalendar))
            }
            completion(.success(true))
        } else {
            completion(.failure(.eventAlreadyExistsInCalendar))
        }
    }

    /// Check if the event was already added to the calendar
    private func eventAlreadyExists(event eventToAdd: EKEvent) -> Bool {
        let predicate = eventStore.predicateForEvents(withStart: eventToAdd.startDate, end: eventToAdd.endDate, calendars: nil)
        let existingEvents = eventStore.events(matching: predicate)

        let eventAlreadyExists = existingEvents.contains { event -> Bool in
            eventToAdd.title == event.title && event.startDate == eventToAdd.startDate && event.endDate == eventToAdd.endDate
        }
        return eventAlreadyExists
    }

    /// Show event kit ui to add event to calendar
    func presentCalendarModalToAddEvent(event: EKEvent, completion: @escaping EventsCalendarManagerResponse) {
        let authStatus = getAuthorizationStatus()
        switch authStatus {
        case .authorized:
            presentEventCalendarDetailModal(event: event)
            completion(.success(true))
        case .notDetermined:
            // Auth is not determined
            // We should request access to the calendar
            requestAccess { accessGranted, _ in
                if accessGranted {
                    self.presentEventCalendarDetailModal(event: event)
                    completion(.success(true))
                } else {
                    // Auth denied, we should display a popup
                    completion(.failure(.calendarAccessDeniedOrRestricted))
                }
            }
        case .denied, .restricted:
            // Auth denied or restricted, we should display a popup
            completion(.failure(.calendarAccessDeniedOrRestricted))
        @unknown default:
            completion(.failure(.calendarAccessDeniedOrRestricted))
        }
    }

    /// Present edit event calendar modal
    func presentEventCalendarDetailModal(event: EKEvent) {
        let event = generateEvent(event: event)
        let eventModalVC = EKEventEditViewController()
        eventModalVC.event = event
        eventModalVC.eventStore = eventStore
        eventModalVC.editViewDelegate = self
        let keyWindow = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .map { $0 as? UIWindowScene }
            .compactMap { $0 }
            .first?.windows
            .filter { $0.isKeyWindow }.first

        if let rootVC = keyWindow?.rootViewController {
            rootVC.present(eventModalVC, animated: true, completion: nil)
        }
    }
}

// EKEventEditViewDelegate
extension EventsCalendarManager: EKEventEditViewDelegate {
    func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith _: EKEventEditViewAction) {
        controller.dismiss(animated: true, completion: nil)
    }
}
