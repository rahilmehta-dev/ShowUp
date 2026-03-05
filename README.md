# ShowUp

> Tasks only auto-complete when you physically show up — and stay.

> ⚡ Vibe coded with [Claude Code](https://claude.ai/code)

ShowUp is an iOS 17+ app that tracks location-based habits. No manual check-offs. You enter a geofenced zone, the timer starts, and when you've stayed long enough the task completes itself.

---

## How It Works

1. **Create a task** — name it, search for a location, pick a duration (15–90 min)
2. **ShowUp monitors your location** in the background using geofencing (150m radius)
3. **Walk into the zone** — the timer starts automatically
4. **Leave the zone** — timer pauses (with an optional 5-min grace period)
5. **Accumulate enough time** — task auto-completes, streak increments, notification fires

---

## Screenshots

| Tasks | Add Task | Detail | Live Activity |
|-------|----------|--------|---------------|
| Pastel cards with live progress rings | MapKit location search | Geofence map + streak history | Dynamic Island + Lock Screen |

---

## Features

### Core
- **Zero manual input** — location + time = completion
- **Geofencing** via `CLLocationManager` + `CLCircularRegion` (150m radius, adjustable)
- **Timer persists** across app kills — uses entry timestamp, not an in-memory timer
- **Multiple tasks** tracked simultaneously
- **Grace period** — optional 5-min buffer before timer pauses on exit

### UI
- Black background with **pastel task cards** (blue, peach, mint, purple, yellow)
- **Live progress rings** on each card, updating every second via `TimelineView`
- **Week date strip** with today highlighted
- **Pulse animation** on cards when actively tracking

### Live Activity
- **Dynamic Island** — compact ring + time remaining while in zone
- **Lock Screen banner** — full progress bar, elapsed time, status
- Smooth animation via `ProgressView(timerInterval:)` — no constant app updates needed
- Toggle on/off in Settings

### Notifications
| Trigger | Message |
|---------|---------|
| Enter zone | 📍 You're at [location] — timer started! |
| Leave zone | ⏸ Timer paused — come back to continue |
| 50% done | Halfway there! Keep going 💪 |
| 80% done | Almost done! Just X mins to go |
| Completed | ✅ [Task] complete! Streak: N days 🔥 |

### Streaks
- Increments on consecutive daily completions
- Resets if a day is missed
- Last 7-day dot history on task detail screen

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI (iOS 17+) |
| Persistence | SwiftData |
| Location | CoreLocation — `CLLocationManager`, `CLCircularRegion` |
| Live Activity | ActivityKit + WidgetKit |
| Notifications | UserNotifications |
| Background | BackgroundTasks (`BGAppRefreshTask`) |
| Maps | MapKit + `MKLocalSearch` |
| Architecture | MVVM + `@Observable` |

---

## Project Structure

```
ShowUp/
├── ShowUpApp.swift                  # App entry, AppDelegate, RootView
├── ShowUpActivityAttributes.swift   # Shared Live Activity model
├── Info.plist
├── Models/
│   ├── ShowUpTask.swift             # @Model — task + daily tracking state
│   ├── LocationRecord.swift         # @Model — visit history
│   └── StreakRecord.swift           # @Model — completion log
├── ViewModels/
│   └── TaskViewModel.swift          # Geofence events → timer → streak → notifications
├── Managers/
│   ├── LocationManager.swift        # CLLocationManager delegate, grace period
│   ├── NotificationManager.swift    # UNUserNotificationCenter
│   ├── LiveActivityManager.swift    # ActivityKit start/update/end
│   └── BackgroundTaskManager.swift  # BGTaskScheduler registration
└── Views/
    ├── ContentView.swift            # TabView
    ├── TaskListView.swift           # Cards, week strip, progress rings
    ├── AddTaskView.swift            # Search + map preview + duration picker
    ├── TaskDetailView.swift         # Map, status, streak dots, progress bar
    ├── MapOverviewView.swift        # All geofences on one map
    ├── HistoryView.swift            # Completion log grouped by day
    └── SettingsView.swift           # Radius, grace period, Live Activity toggle

ShowUpWidgetExtension/
├── ShowUpWidgetBundle.swift         # @main for widget target
└── ShowUpLiveActivity.swift         # Lock Screen + Dynamic Island UI
```

---

## Requirements

- iOS 17.0+
- Xcode 15+
- Real device (geofencing does not work in Simulator)
- Location permission: **Always On** (required for background geofence delivery)

## Setup

1. Clone the repo
2. Open `ShowUp.xcodeproj`
3. Set your **Development Team** in Signing & Capabilities for both targets (`ShowUp` and `ShowUpWidgetExtension`)
4. Run on a physical iPhone

---

## Permissions Required

| Permission | Reason |
|-----------|--------|
| Location — Always | Detect zone entry/exit in background |
| Notifications | Progress and completion alerts |
| Live Activities | Dynamic Island + Lock Screen timer |

---

## License

MIT
