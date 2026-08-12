//
//  EventKitManager.swift
//  NitroEventKitX
//
//  Created by VLAD on 04.02.2025.
//

import Foundation
import EventKit

final class EventKitManager {
    static let shared = EventKitManager()

    let eventStore = EKEventStore()

    private init() {}

    /// Recomputed on every read rather than cached: the user can flip either
    /// switch in Settings while the app is running, and a flag captured at
    /// launch would keep answering with the state from launch.
    var isCalendarAccessAvailable: Bool {
        Self.hasFullAccess(to: .event)
    }

    /// Calendars and Reminders are separate authorizations — granting one says
    /// nothing about the other.
    var isRemindersAccessAvailable: Bool {
        Self.hasFullAccess(to: .reminder)
    }

    private static func hasFullAccess(to entityType: EKEntityType) -> Bool {
        let status = EKEventStore.authorizationStatus(for: entityType)

        if #available(iOS 17.0, *) {
            // Write-only is a real granted state on iOS 17+, and it cannot read.
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }
}
