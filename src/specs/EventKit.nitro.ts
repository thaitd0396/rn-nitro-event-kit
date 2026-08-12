import { type HybridObject } from 'react-native-nitro-modules'
import type {
  CreateCalendarOptions,
  CreateEventOptions,
  EditEventOptions,
  EventKitCalendar,
  EventKitEvent,
  EventKitReminder,
  MonthlyEventOptions,
  RangeEventOptions,
  RangeReminderOptions,
} from './types'

export interface EventKit extends HybridObject<{ ios: 'swift' }> {
  getActiveCalendars(): Promise<EventKitCalendar[]>
  getReminderCalendars(): Promise<EventKitCalendar[]>
  getMonthlyCalendarEvents(
    options: MonthlyEventOptions
  ): Promise<EventKitEvent[]>
  getCalendarEventsByRange(options: RangeEventOptions): Promise<EventKitEvent[]>
  getReminders(options: RangeReminderOptions): Promise<EventKitReminder[]>
  createEvent(options: CreateEventOptions): Promise<EventKitEvent>
  deleteEvent(eventIdentifier: string): Promise<boolean>
  openCalendarEvent(eventIdentifier: string): Promise<void>
  createCalendar(options: CreateCalendarOptions): Promise<EventKitCalendar>
  editEvent(
    eventIdentifier: string,
    options: EditEventOptions
  ): Promise<EventKitEvent>
}
