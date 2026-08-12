# rn-nitro-event-kit

Read Apple Calendar events and Apple Reminders from React Native, through
[Nitro](https://nitro.margelo.com) (Swift, New Architecture, no bridge).

A fork of
[react-native-nitro-event-kit](https://github.com/VladyslavMartynov10/react-native-nitro-event-kit)
by Vlad Martynov. See [What this fork changes](#what-this-fork-changes).

## Requirements

- React Native 0.75+, New Architecture
- iOS 16+
- `react-native-nitro-modules` >= 0.35

## Installation

```sh
npm install rn-nitro-event-kit react-native-nitro-modules
cd ios && pod install
```

Add the usage descriptions you actually need to `Info.plist`. On iOS 17+ these
are two separate permissions with two separate keys — granting one tells you
nothing about the other:

| Key | Needed for |
| --- | --- |
| `NSCalendarsFullAccessUsageDescription` | reading calendar events |
| `NSRemindersFullAccessUsageDescription` | reading reminders |

`NSCalendarsUsageDescription` is the pre-iOS-17 spelling; keep it too if you
still deploy to iOS 16.

## Usage

```ts
import {
  NitroEventKit,
  NitroEventKitCalendarPermission,
  EventKitReminderCompletion,
} from 'rn-nitro-event-kit'

const status = await NitroEventKitCalendarPermission.requestPermission()
if (status === 'fullAccess') {
  const events = await NitroEventKit.getCalendarEventsByRange({
    startDate: Date.now(),
    endDate: Date.now() + 7 * 24 * 60 * 60 * 1000,
  })
  console.log(events[0].title, events[0].calendarTitle)
}

const remindersStatus =
  await NitroEventKitCalendarPermission.requestRemindersPermission()
if (remindersStatus === 'fullAccess') {
  const reminders = await NitroEventKit.getReminders({
    completion: EventKitReminderCompletion.Incomplete,
  })
}
```

Note that `writeOnly` is a real answer on iOS 17+, and it cannot read a single
event — check for `'fullAccess'` rather than for "not denied".

### Permissions

| Method | Notes |
| --- | --- |
| `getPermissionsStatus()` | calendars, synchronous |
| `requestPermission()` | calendars |
| `getRemindersPermissionsStatus()` | reminders, synchronous |
| `requestRemindersPermission()` | reminders |

All four answer with `'unavailable' \| 'denied' \| 'restricted' \|
'fullAccess' \| 'writeOnly' \| 'notDetermined'`.

### Events

| Method | Notes |
| --- | --- |
| `getActiveCalendars()` | event calendars |
| `getCalendarEventsByRange({ startDate, endDate, calendarId? })` | ms timestamps |
| `getMonthlyCalendarEvents({ calendarId? })` | now → +31 days |
| `createEvent(options)` / `editEvent(id, options)` / `deleteEvent(id)` | |
| `openCalendarEvent(id)` | presents the native event preview |
| `createCalendar(options)` | `entityType` picks event calendar vs reminder list |

EventKit caps `predicateForEvents` at a four-year span and silently clamps
anything longer, so ask for the range you need.

### Reminders

| Method | Notes |
| --- | --- |
| `getReminderCalendars()` | reminder lists |
| `getReminders({ completion, startDate?, endDate?, calendarId? })` | |

`completion` selects the predicate, which is what the date range then means:

- `Incomplete` — range bounds the **due date**
- `Completed` — range bounds the **completion date**
- `All` — EventKit has no ranged predicate here, so the range is applied to the
  due date after fetching, and undated reminders are kept

`dueDate` is resolved from `DateComponents`, so a reminder set for a day with no
time lands on local midnight. `isDueDateTimed` is how you tell that apart from a
reminder genuinely due at 00:00.

## What this fork changes

- **Events carry their content.** Upstream's `EventKitEvent` mapped only
  identifiers and timestamps, so a caller could see *when* the user was busy but
  never *what* with. Added `title`, `notes`, `location`, `url`, `timeZone`,
  `calendarIdentifier`, `calendarTitle` and `hasAlarms`.
- **Reminders actually work.** Upstream requested authorization for `.event`
  only and answered `entityType: Reminder` with `predicateForEvents` +
  `events(matching:)`, which returns an empty array for a reminder calendar —
  silently, so it read as "no reminders". Reminders now have their own
  permission pair, their own predicates (`predicateForIncompleteReminders` /
  `predicateForCompletedReminders` / `predicateForReminders`) and
  `fetchReminders`.
- **`entityType` is gone from the event-read options.** `events(matching:)` can
  only ever return events, so the field could not do what it claimed. Reminders
  go through `getReminders`. It remains on `CreateCalendarOptions`, where it
  genuinely chooses between an event calendar and a reminder list.
- **Permission results are read back from the OS** instead of resolving
  `fullAccess` whenever the request reported `granted` — that reported
  `fullAccess` for a user who had granted write-only.
- **Authorization is no longer cached at launch.** Upstream computed access once
  in the `EventKitManager` singleton, so revoking permission in Settings left
  the app convinced it still had it for the rest of the session.
- **One predicate per query instead of one per calendar**, and nil-safe mapping
  of EventKit's implicitly unwrapped optionals.
- Regenerated with **nitrogen 0.35.10**. Upstream shipped output built by
  `nitro-codegen` 0.29.4, which does not match a modern
  `react-native-nitro-modules` runtime.
- The pod and C++ namespace are renamed (`NitroEventKitX`, `eventkitx`) so this
  fork can coexist with upstream.

## Development

```sh
npm install
npm run codegen   # nitrogen + bob build
npm run typecheck
```

## License

MIT — see [License.md](./License.md). Original copyright Vladyslav Martynov.
