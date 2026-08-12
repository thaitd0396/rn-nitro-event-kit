//
//  HybridCalendarPermission.swift
//  NitroEventKitX
//
//  Created by VLAD on 04.02.2025.
//

import Foundation
import NitroModules
import EventKit

class HybridCalendarPermission: HybridCalendarPermissionSpec {
    private let eventStore = EventKitManager.shared.eventStore

    func getPermissionsStatus() throws -> EventKitPermissionResult {
        parseStatus(EKEventStore.authorizationStatus(for: .event))
    }

    func requestPermission() throws -> NitroModules.Promise<EventKitPermissionResult> {
        requestAccess(to: .event)
    }

    func getRemindersPermissionsStatus() throws -> EventKitPermissionResult {
        parseStatus(EKEventStore.authorizationStatus(for: .reminder))
    }

    func requestRemindersPermission() throws -> NitroModules.Promise<EventKitPermissionResult> {
        requestAccess(to: .reminder)
    }

    private func requestAccess(to entityType: EKEntityType) -> NitroModules.Promise<EventKitPermissionResult> {
        let promise = Promise<EventKitPermissionResult>()

        let completionHandler: EKEventStoreRequestAccessCompletionHandler = { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    promise.reject(withError: error)
                    return
                }

                // Reading the status back rather than trusting the `granted`
                // flag: on iOS 17+ a user can grant write-only, which arrives
                // here as granted but still cannot read a single event.
                promise.resolve(
                    withResult: self.parseStatus(EKEventStore.authorizationStatus(for: entityType))
                )
            }
        }

        if #available(iOS 17.0, *) {
            // The deprecated requestAccess(to:) grants only write access to an
            // app linked against the iOS 17 SDK, so reads would come back empty
            // forever — see TN3153.
            switch entityType {
            case .event:
                eventStore.requestFullAccessToEvents(completion: completionHandler)
            case .reminder:
                eventStore.requestFullAccessToReminders(completion: completionHandler)
            @unknown default:
                promise.resolve(withResult: .unavailable)
            }
        } else {
            eventStore.requestAccess(to: entityType, completion: completionHandler)
        }

        return promise
    }

    private func parseStatus(_ status: EKAuthorizationStatus) -> EventKitPermissionResult {
        switch status {
        case .denied:
            return .denied
        case .notDetermined:
            return .notdetermined
        case .restricted:
            return .restricted
        case .fullAccess:
            return .fullaccess
        case .writeOnly:
            return .writeonly
        @unknown default:
            return .unavailable
        }
    }
}
