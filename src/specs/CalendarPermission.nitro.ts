import { type HybridObject } from 'react-native-nitro-modules'
import type { EventKitPermissionResult } from './types'

/**
 * Calendars and Reminders are two separate EventKit authorizations with two
 * separate Info.plist keys, and granting one says nothing about the other —
 * hence four methods rather than an entity-type argument.
 */
export interface CalendarPermission extends HybridObject<{ ios: 'swift' }> {
  getPermissionsStatus(): EventKitPermissionResult
  requestPermission(): Promise<EventKitPermissionResult>
  getRemindersPermissionsStatus(): EventKitPermissionResult
  requestRemindersPermission(): Promise<EventKitPermissionResult>
}
