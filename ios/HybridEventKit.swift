//
//  HybridEventKit.swift
//  NitroEventKitX
//
//  Created by VLAD on 03.02.2025.
//

import Foundation
import NitroModules
import UIKit
import EventKit
import EventKitUI

class HybridEventKit: HybridEventKitSpec {
    private let eventStore = EventKitManager.shared.eventStore
    
    private func checkCalendarAvailability() throws {
        guard EventKitManager.shared.isCalendarAccessAvailable else {
            throw RuntimeError.error(withMessage: EventKitError.calendarAvailability.message)
        }
    }

    private func checkRemindersAvailability() throws {
        guard EventKitManager.shared.isRemindersAccessAvailable else {
            throw RuntimeError.error(withMessage: EventKitError.remindersAvailability.message)
        }
    }

    /// `nil` is what EventKit's predicates take to mean "every calendar".
    private func calendars(matching calendarId: String?) throws -> [EKCalendar]? {
        guard let calendarId = calendarId else { return nil }
        return [try getCalendar(by: calendarId)]
    }

    private func events(from startDate: Date, to endDate: Date, calendarId: String?) throws -> [EventKitEvent] {
        // One predicate spanning every calendar, rather than one predicate per
        // calendar: an event belongs to exactly one calendar, so the union is
        // the same set of events for a fraction of the EventKit round trips.
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: try calendars(matching: calendarId)
        )

        return eventStore.events(matching: predicate).map(mapToNitroEvent)
    }

    /// EventKit answers reminder fetches on its own queue through a callback and
    /// ships no async variant, so the bridge to Swift concurrency is manual.
    private func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { continuation in
            self.eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    /// A reminder with no due date is kept — it is undated, not out of range.
    private static func isDueDate(of reminder: EKReminder, within start: Date?, and end: Date?) -> Bool {
        guard let due = date(from: reminder.dueDateComponents) else { return true }
        if let start = start, due < start { return false }
        if let end = end, due > end { return false }
        return true
    }

    private func getCalendar(by identifier: String) throws -> EKCalendar {
        guard let calendar = self.eventStore.calendar(withIdentifier: identifier) else {
            throw RuntimeError.error(withMessage: EventKitError.calendarExistence.message)
        }
        
        return calendar
    }
    
    private func getEvent(by identifier: String) throws -> EKEvent {
        guard let event = self.eventStore.event(withIdentifier: identifier) else {
            throw RuntimeError.error(withMessage: EventKitError.eventIdentifierNotFound.message)
        }
        
        return event
    }

    func getMonthlyCalendarEvents(options: MonthlyEventOptions) throws -> NitroModules.Promise<[EventKitEvent]> {
        return Promise.async {
            try self.checkCalendarAvailability()

            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: 31, to: startDate) ?? startDate

            return try self.events(from: startDate, to: endDate, calendarId: options.calendarId)
        }
    }

    func getCalendarEventsByRange(options: RangeEventOptions) throws -> NitroModules.Promise<[EventKitEvent]> {
        return Promise.async {
            try self.checkCalendarAvailability()

            return try self.events(
                from: options.startDate.asDateFromMilliseconds,
                to: options.endDate.asDateFromMilliseconds,
                calendarId: options.calendarId
            )
        }
    }

    func getReminders(options: RangeReminderOptions) throws -> NitroModules.Promise<[EventKitReminder]> {
        return Promise.async {
            try self.checkRemindersAvailability()

            let calendars = try self.calendars(matching: options.calendarId)
            let start = options.startDate?.asDateFromMilliseconds
            let end = options.endDate?.asDateFromMilliseconds

            let predicate: NSPredicate
            let needsDueDateFilter: Bool

            switch options.completion {
            case .incomplete:
                predicate = self.eventStore.predicateForIncompleteReminders(
                    withDueDateStarting: start,
                    ending: end,
                    calendars: calendars
                )
                needsDueDateFilter = false
            case .completed:
                predicate = self.eventStore.predicateForCompletedReminders(
                    withCompletionDateStarting: start,
                    ending: end,
                    calendars: calendars
                )
                needsDueDateFilter = false
            case .all:
                // predicateForReminders(in:) accepts no range, so this is the
                // one case that has to bound the result after fetching.
                predicate = self.eventStore.predicateForReminders(in: calendars)
                needsDueDateFilter = start != nil || end != nil
            }

            let reminders = await self.fetchReminders(matching: predicate)

            guard needsDueDateFilter else {
                return reminders.map(self.mapToNitroReminder)
            }

            return reminders
                .filter { Self.isDueDate(of: $0, within: start, and: end) }
                .map(self.mapToNitroReminder)
        }
    }
    
    func createEvent(options: CreateEventOptions) throws -> NitroModules.Promise<EventKitEvent> {
        return Promise.async {
            try self.checkCalendarAvailability()
            
            let calendar = try self.getCalendar(by: options.calendarIdentifier)
            
            let newEvent = EKEvent(eventStore: self.eventStore)
            
            newEvent.startDate = options.startDate.asDateFromMilliseconds
            
            newEvent.endDate = options.endDate.asDateFromMilliseconds

            newEvent.calendar = calendar
            
            newEvent.notes = options.notes
            
            newEvent.title = options.title
            
            if let location = options.location {
                let structuredLocation = EKStructuredLocation(
                    title: location.title ?? ""
                )
                
                structuredLocation.geoLocation = CLLocation(
                    latitude: location.latitude,
                    longitude: location.longitude
                )
                
                newEvent.location = location.title
                newEvent.structuredLocation = structuredLocation
            }
            
            if let minutesBefore = options.scheduleAlarmMinutesBefore, let scheduleAlarm = options.scheduleAlarm, scheduleAlarm {
                let secondsPerMinute: TimeInterval = 60
                let alarm = EKAlarm(relativeOffset: TimeInterval(minutesBefore * -secondsPerMinute))
                newEvent.addAlarm(alarm)
            }

            do {
                try self.eventStore.save(newEvent, span: .thisEvent)
                
                return self.mapToNitroEvent(newEvent)
            } catch {
                throw RuntimeError.error(withMessage: EventKitError.eventCreationFailed.message)
            }
        }
    }
    
    func deleteEvent(eventIdentifier: String) -> NitroModules.Promise<Bool> {
        return Promise.async {
            try self.checkCalendarAvailability()
            
            let event = try self.getEvent(by: eventIdentifier)
            
            do {
                try self.eventStore.remove(event, span: .thisEvent)
                
                return true
            } catch {
                throw RuntimeError.error(withMessage: EventKitError.eventCreationFailed.message)
            }
        }
    }
    
    func getActiveCalendars() throws -> NitroModules.Promise<[EventKitCalendar]> {
        return Promise.async {
            try self.checkCalendarAvailability()

            let calendars = self.eventStore.calendars(for: .event).map { self.mapToNitroCalendar($0) }

            return calendars
        }
    }

    func getReminderCalendars() throws -> NitroModules.Promise<[EventKitCalendar]> {
        return Promise.async {
            try self.checkRemindersAvailability()

            return self.eventStore.calendars(for: .reminder).map { self.mapToNitroCalendar($0) }
        }
    }
    
    func openCalendarEvent(eventIdentifier: String) throws -> NitroModules.Promise<Void> {
           try self.checkCalendarAvailability()

           let promise = Promise<Void>()
        
           DispatchQueue.main.async {
               guard let rootViewController = UIApplication.shared.rootViewController else {
                   promise.reject(withError: EventKitError.rootViewControllerNotFound.nsError)
                   return
               }
            
               let eventPreviewController = EventPreviewController(eventIdentifier: eventIdentifier)
               
               let navigationController = UINavigationController(rootViewController: eventPreviewController)

               rootViewController.present(navigationController, animated: true) {
                   promise.resolve(withResult: ())
               }
           }

           return promise
    }
    
    func createCalendar(options: CreateCalendarOptions) throws -> NitroModules.Promise<EventKitCalendar> {
        return Promise.async {
            try self.checkCalendarAvailability()
            
            let calendar = EKCalendar(
                for: self.mapToEVKitEntityType(options.entityType),
                eventStore: self.eventStore
            )
            
            calendar.title = options.name
            
            if let colorHex = options.cgColor,
               let color = UIColor(hexString: colorHex) {
                calendar.cgColor = color.cgColor
            }
            
            if let sourceTypeRaw = options.sourceType {
                let sourceType = self.mapToEVKitSourceType(sourceTypeRaw)
                
                if let matchedSource = self.eventStore.sources.first(
                    where: { $0.sourceType == sourceType }
                ) {
                    calendar.source = matchedSource
                } else {
                    throw RuntimeError.error(
                        withMessage: EventKitError.calendarSourceInvalid.message
                    )
                }
            } else if let localSource = self.eventStore.sources.first(
                where: { $0.sourceType == .local }
            ) {
                calendar.source = localSource
            } else if let defaultSource = self.eventStore.defaultCalendarForNewEvents?.source {
                calendar.source = defaultSource
            } else {
                throw RuntimeError.error(
                    withMessage: EventKitError.calendarSourceNotFound.message
                )
            }

            
            do {
                try self.eventStore.saveCalendar(calendar, commit: true)
                
                return self.mapToNitroCalendar(calendar)
            } catch {
                throw RuntimeError.error(
                    withMessage: EventKitError.calendarSavingFailed.message
                )
            }
        }
    }
    
    
    func editEvent(eventIdentifier: String, options: EditEventOptions) throws -> NitroModules.Promise<EventKitEvent> {
        return Promise.async {
            try self.checkCalendarAvailability()

            guard let event = self.eventStore.event(withIdentifier: eventIdentifier) else {
                throw RuntimeError.error(
                    withMessage: EventKitError.eventIdentifierNotFound.message
                )
            }
            
            if let newTitle = options.title {
                event.title = newTitle
            }

            if let newStartDate = options.startDate {
                event.startDate = newStartDate.asDateFromMilliseconds
            }

            if let newEndDate = options.endDate {
                event.endDate = newEndDate.asDateFromMilliseconds
            }

            if let newNotes = options.notes {
                event.notes = newNotes
            }

            if let newLocation = options.location {
                let structuredLocation = EKStructuredLocation(
                    title: newLocation.title ?? ""
                )
                
                if let newLatitude = newLocation.latitude, let newLongitude = newLocation.longitude {
                    structuredLocation.geoLocation = CLLocation(
                        latitude: newLatitude,
                        longitude: newLongitude
                    )
                }
                
                
                event.location = newLocation.title
                event.structuredLocation = structuredLocation
            }
            
            if let minutesBefore = options.scheduleAlarmMinutesBefore, let scheduleAlarm = options.scheduleAlarm, scheduleAlarm {
                let secondsPerMinute: TimeInterval = 60
                let alarm = EKAlarm(relativeOffset: TimeInterval(minutesBefore * -secondsPerMinute))
                event.addAlarm(alarm)
            }

            if let newCalendarId = options.calendarId {
                guard let targetCalendar = self.eventStore.calendars(for: .event).first(
                    where: { $0.calendarIdentifier == newCalendarId }) else {
                    throw RuntimeError
                        .error(
                            withMessage: EventKitError.calendarExistence.message
                        )
                }
                
                event.calendar = targetCalendar
            }

            do {
                try self.eventStore.save(event, span: .thisEvent, commit: true)
                return self.mapToNitroEvent(event)
            } catch {
                throw RuntimeError.error(
                    withMessage: EventKitError.eventUpdateFailed.message
                )
            }
        }
    }
}
