export enum EventKitAvailability {
  NotSupported = -1,
  Busy = 0,
  Free = 1,
  Tentative = 2,
  Unavailable = 3,
}

export enum EventKitStatus {
  None = 0,
  Confirmed = 1,
  Tentative = 2,
  Canceled = 3,
}

export enum EventKitParticipantRole {
  Unknown = 0,
  Required = 1,
  Optional = 2,
  Chair = 3,
  NonParticipant = 4,
}

export enum EventKitParticipantStatus {
  Unknown = 0,
  Pending = 1,
  Accepted = 2,
  Declined = 3,
  Tentative = 4,
  Delegated = 5,
  Completed = 6,
  InProcess = 7,
}

export interface EventKitSource {
  sourceIdentifier: string
  sourceType: EventKitSourceType
  title: string
  isDelegate?: boolean
}

export enum EventKitAuthorizationStatus {
  NotDetermined = 0,
  Restricted = 1,
  Denied = 2,
  FullAccess = 3,
  WriteOnly = 4,
}

export enum EventKitWeekday {
  Sunday = 1,
  Monday = 2,
  Tuesday = 3,
  Wednesday = 4,
  Thursday = 5,
  Friday = 6,
  Saturday = 7,
}

export enum EventKitRecurrenceFrequency {
  Daily = 0,
  Weekly = 1,
  Monthly = 2,
  Yearly = 3,
}

export enum EventKitParticipantType {
  Unknown = 0,
  Person = 1,
  Room = 2,
  Resource = 3,
  Group = 4,
}

export enum EventKitParticipantScheduleStatus {
  None = 0,
  Pending = 1,
  Sent = 2,
  Delivered = 3,
  RecipientNotRecognized = 4,
  NoPrivileges = 5,
  DeliveryFailed = 6,
  CannotDeliver = 7,
  RecipientNotAllowed = 8,
}

export enum EventKitCalendarType {
  Local = 0,
  CalDAV = 1,
  Exchange = 2,
  Subscription = 3,
  Birthday = 4,
}

export interface EventKitCalendarEventAvailabilityMask {
  Busy?: boolean
  Free?: boolean
  Tentative?: boolean
  Unavailable?: boolean
}

export enum EventKitSourceType {
  Local = 0,
  Exchange = 1,
  CalDAV = 2,
  MobileMe = 3,
  Subscribed = 4,
  Birthdays = 5,
}

export enum EventKitEntityType {
  Event = 0,
  Reminder = 1,
}

export interface EventKitEntityMask {
  Event?: boolean
  Reminder?: boolean
}

export enum EventKitAlarmProximity {
  None = 0,
  Enter = 1,
  Leave = 2,
}

export enum EventKitAlarmType {
  Display = 0,
  Audio = 1,
  Procedure = 2,
  Email = 3,
}

export enum EventKitReminderPriority {
  None = 0,
  High = 1,
  Medium = 5,
  Low = 9,
}

export interface EventKitCoordinate {
  latitude: number
  longitude: number
}

export interface EventKitGeoLocation {
  coordinate: EventKitCoordinate
  altitude: number
  ellipsoidalAltitude: number
  horizontalAccuracy: number
  verticalAccuracy: number
  course: number
  courseAccuracy: number
  speed: number
  speedAccuracy: number
  timestamp: number
}

export interface EventKitStructuredLocation {
  title?: string
  geoLocation?: EventKitGeoLocation
  radius: number
}

export interface EventKitPredicate {
  predicateFormat: string
}

export interface EventKitParticipant {
  url: string
  name?: string
  participantStatus: EventKitParticipantStatus
  participantRole: EventKitParticipantRole
  participantType: EventKitParticipantType
  isCurrentUser: boolean
  contactPredicate: EventKitPredicate
}

export interface EventKitEvent {
  eventIdentifier: string
  /** Empty string when the event has no title; `EKEvent.title` is nullable. */
  title: string
  notes?: string
  location?: string
  url?: string
  timeZone?: string
  calendarIdentifier: string
  calendarTitle: string
  isAllDay: boolean
  startDate: number
  endDate: number
  hasAlarms: boolean
  structuredLocation?: EventKitStructuredLocation
  organizer?: EventKitParticipant
  availability: EventKitAvailability
  status: EventKitStatus
  isDetached: boolean
  occurrenceDate?: number
  birthdayContactIdentifier?: string
  createdAt: number
  updatedAt: number
}

/**
 * A single Reminders item.
 *
 * `dueDate` and `startDate` come from `DateComponents`, so a reminder with a
 * day but no time resolves to local midnight — check `isDueDateTimed` before
 * showing a clock time.
 */
export interface EventKitReminder {
  reminderIdentifier: string
  title: string
  notes?: string
  isCompleted: boolean
  completionDate?: number
  dueDate?: number
  isDueDateTimed: boolean
  startDate?: number
  /** Raw EventKit priority, 0 = none, 1 (highest) to 9 (lowest). */
  priority: number
  hasAlarms: boolean
  hasRecurrenceRules: boolean
  calendarIdentifier: string
  calendarTitle: string
  createdAt: number
  updatedAt: number
}

export enum EventKitReminderCompletion {
  All = 0,
  Incomplete = 1,
  Completed = 2,
}

export type EventKitPermissionResult =
  | 'denied'
  | 'notDetermined'
  | 'restricted'
  | 'fullAccess'
  | 'writeOnly'
  | 'unavailable'

export interface EventKitCalendar {
  calendarIdentifier: string
  title: string
  type: EventKitCalendarType
  allowsContentModifications: boolean
  isSubscribed?: boolean
  isImmutable?: boolean
  cgColor?: string
  supportedEventAvailabilities: EventKitCalendarEventAvailabilityMask
  allowedEntityTypes: EventKitEntityMask
  source: EventKitSource
}

export interface CreateEventLocation {
  title?: string
  latitude: number
  longitude: number
}

export interface CreateEventOptions {
  startDate: number
  endDate: number
  title: string
  location?: CreateEventLocation
  notes?: string
  calendarIdentifier: string
  isCalendarImmutable: boolean
  scheduleAlarm?: boolean
  scheduleAlarmMinutesBefore?: number
}

// `entityType` is deliberately absent here, unlike upstream: `events(matching:)`
// only ever returns EKEvents, so asking it for `Reminder` returned an empty
// array rather than an error. Reminders have their own predicate and their own
// method — see `getReminders`.
export interface RangeEventOptions {
  startDate: number
  endDate: number
  calendarId?: string
}

export interface MonthlyEventOptions {
  calendarId?: string
}

/**
 * `startDate`/`endDate` bound the due date for `Incomplete`, and the completion
 * date for `Completed` — that is the only range EventKit's reminder predicates
 * accept. Omit both for no bound. Under `All` they are applied to the due date
 * after fetching, and reminders with no due date are kept.
 */
export interface RangeReminderOptions {
  startDate?: number
  endDate?: number
  completion: EventKitReminderCompletion
  calendarId?: string
}

export interface CreateCalendarOptions {
  name: string
  cgColor?: string
  entityType: EventKitEntityType
  sourceType?: EventKitSourceType
}

export interface EditEventLocation {
  title?: string
  latitude?: number
  longitude?: number
}

export interface EditEventOptions {
  title?: string
  startDate?: number
  endDate?: number
  location?: EditEventLocation
  notes?: string
  scheduleAlarm?: boolean
  scheduleAlarmMinutesBefore?: number
  calendarId?: string
}
