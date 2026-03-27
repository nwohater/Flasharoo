# Flasharoo — Development TODO

> Track progress here. Statuses: `[ ]` not started · `[~]` in progress · `[x]` done

---

## Phase 1 — Project foundation

- [x] Configure bundle ID and iCloud container (`iCloud.com.golackey.flasharoo`)
- [x] Add CloudKit capability to Xcode project
- [x] Add Background Modes capability (background fetch, background processing)
- [x] Replace boilerplate `Item.swift` / `ContentView.swift` with app shell
- [x] Set up `FlasharooApp.swift` with `ModelContainer` + CloudKit config
- [x] Define all SwiftData models (Deck, Card, CardReview, MediaAsset, FilteredDeck, GestureSettings, UserSettings)
- [x] Define all enumerations (CardState, SchedulerAlgorithm, CardFlag, MediaType, etc.)
- [x] Basic `NavigationSplitView` shell (sidebar + detail, adaptive iPhone/iPad/Mac)

---

## Phase 2 — Core data layer

- [x] `Deck` CRUD (create, rename, delete with soft-delete)
- [x] `Card` CRUD (front/back HTML, tags, flags)
- [x] `CardReview` insert (append-only, never updated)
- [x] `UserSettings` singleton creation and access
- [x] `GestureSettings` default creation (global + per-deck fallthrough)
- [x] `BackgroundDataActor` scaffold (ModelActor for heavy operations)
- [ ] Verify SwiftData ↔ CloudKit sync in simulator (two-device simulation)

---

## Phase 3 — Scheduling engine

- [x] `SchedulerService` actor scaffold
- [x] SM-2 algorithm implementation + unit tests (verify against reference values)
- [x] FSRS v5 algorithm implementation + unit tests (verify against reference values)
- [x] `ScheduleResult` / `CardState` transitions (new → learning → review)
- [x] New card daily limit enforcement per deck
- [x] Study queue builder (`buildStudyQueue` — returns `[PersistentIdentifier]`)
- [x] `dueTodayCount`, `overdueCards`, `forecastNewCards` on `SchedulerService`
- [x] Interval hint labels for answer buttons (e.g. "Again: 10 min · Good: 4d")

---

## Phase 4 — Study interface

- [x] `StudyViewModel` — queue management, card advance, undo last rating
- [x] Card flip view (front → back transition, 60fps)
- [x] Rating buttons row (Again / Hard / Good / Easy + interval hints)
- [x] 9-zone configurable tap area (`TapZoneView`)
- [x] 4-direction swipe gesture recognizer
- [x] Gesture → action dispatch (reads from `GestureSettings`)
- [x] Toolbar with 6 configurable action buttons
- [x] Flag card action
- [x] Skip card action
- [x] Undo last rating action
- [x] Session summary screen (retention %, breakdown, forecast, time)
- [x] Keyboard shortcuts (Space, 1–4, ⌘E, ⌘Z, ⌘F, ⌘N, ⌘,)

---

## Phase 5 — Card editor

- [x] Rich-text / HTML card editor (front + back)
- [x] Tag input with autocomplete
- [x] Image attachment (photo library + camera)
- [x] Image re-compression on import (>5 MB → JPEG 85%)
- [x] Audio attachment (file import; reject >5 min)
- [ ] Drawing button in formatting toolbar (opens `DrawingCanvasView`) — Phase 7
- [ ] `asset://` URL scheme handler for card HTML → local file resolution — Phase 6
- [ ] Card preview (rendered via `CardWebView`) — Phase 6

---

## Phase 6 — MathJax rendering

- [x] Bundle MathJax 3 (`tex-chtml-full`, 1.3 MB) in app resources
- [x] `card.css` with dark mode (`prefers-color-scheme`)
- [x] `RenderService` — HTML template with `{{CONTENT}}` substitution
- [x] `CardWebView` (`UIViewRepresentable` with reused WKWebView instance)
- [x] Height reporting via JS → `webkit.messageHandlers.heightReported`
- [x] Reuse single `WKWebView` instance per session (replace HTML, don't reload)
- [ ] Verify <200ms first render, <50ms subsequent on device

---

## Phase 7 — Apple Pencil / drawing

- [ ] `DrawingCanvasView` (`UIViewRepresentable` wrapping `PKCanvasView`)
- [ ] `PKToolPicker` integration (iPad floating palette, iPhone bottom sheet)
- [ ] Mac: mouse/trackpad input, fixed pressure, floating panel
- [ ] Save drawing: `PKDrawing` data → `MediaAsset` (.drawing) + PNG export → `MediaAsset` (.image)
- [ ] Re-open existing drawing for editing (load `PKDrawing` from stored data)
- [ ] Embed PNG in card HTML via `<img src="asset://{assetID}">`

---

## Phase 8 — Media sync (CloudKit)

- [ ] `MediaService` actor (save, load, thumbnail, delete, pendingUploads, pendingDownloads)
- [ ] Local file storage layout (`Application Support/media/{cardID}/{assetID}.ext`)
- [ ] Thumbnail generation and caching
- [ ] CKAsset upload after local save (background `CKModifyRecordsOperation`)
- [ ] CKAsset download on first card display when `syncState == .downloadNeeded`
- [ ] Placeholder image while download is pending
- [ ] Exponential backoff retry for failed uploads (1min / 5min / 30min)
- [ ] `BGAppRefreshTask` registration and scheduling (`com.yourdomain.flasharoo.mediasync`)
- [ ] Storage warning banner at >1 GB total media

---

## Phase 9 — Search and filtered decks

- [ ] `SearchService` actor scaffold
- [ ] Query language parser (tag:, deck:, state:, rated:, due:, created:, flag:, has:, front:, back:, bare text, `-` negation)
- [ ] `SearchPredicate` → `NSCompoundPredicate` compiler
- [ ] SQLite FTS5 fallback for full-text predicates
- [ ] Paginated results (50 per page, load on scroll)
- [ ] Search bar with real-time results in deck browser
- [ ] Autocomplete for tags, deck names, predicate keywords
- [ ] Query builder sheet (dropdown/date picker UI → query string)
- [ ] `FilteredDeck` CRUD
- [ ] Filtered deck as study source (respects `rescheduleCards` flag)

---

## Phase 10 — Statistics

- [ ] `StatsViewModel` scaffold
- [ ] Daily review aggregation (`DailyReviewSummary`)
- [ ] Retention heatmap (custom `Canvas`, 12×12pt cells, blue ramp, tap for popover)
- [ ] Daily review bar chart — last 30 days, stacked new/learning/review (Swift Charts)
- [ ] Forecast bar chart — next 30 days (Swift Charts)
- [ ] Card state breakdown pie chart (Swift Charts)
- [ ] Ease factor histogram (Swift Charts)
- [ ] Interval distribution histogram (Swift Charts)
- [ ] Stability distribution — FSRS only (Swift Charts)
- [ ] True retention curve — FSRS only (Swift Charts)
- [ ] Streak calculation (current + longest)
- [ ] Global stats screen
- [ ] Per-deck stats screen
- [ ] All aggregations run in `BackgroundDataActor`

---

## Phase 11 — Sync polish and error handling

- [ ] `SyncMonitor` — subscribe to `NSPersistentCloudKitContainer.Event` notifications
- [ ] Sync status indicator in toolbar (idle / spinning / error icon)
- [ ] Sync status popover (last sync time, error message)
- [ ] Soft-delete cleanup job (purge `deletedAt` records older than 30 days)
- [ ] CloudKit error handling: networkUnavailable, quotaExceeded, notAuthenticated, zoneNotFound
- [ ] SwiftData error handling: save failure retry, migration error with reset option
- [ ] `ModelContainer` init failure alert (with support contact)
- [ ] Orphaned card handling (deck deleted mid-sync → "Unsorted" virtual deck)

---

## Phase 12 — Settings UI

- [ ] Settings screen scaffold
- [ ] Default scheduling algorithm (SM-2 / FSRS)
- [ ] Show/hide interval hints
- [ ] Autoplay audio toggle
- [ ] Day start hour (default 4am)
- [ ] Theme (system / light / dark)
- [ ] Gesture customisation UI (tap zone grid + swipe pickers)
- [ ] Toolbar customisation UI (drag to reorder, up to 6 actions)
- [ ] Per-deck settings override

---

## Phase 13 — Polish and pre-release

- [ ] App icon (all required sizes)
- [ ] Launch screen
- [ ] Onboarding flow (first launch)
- [ ] iPad multitasking decision (Split View or full screen lock) — resolve open question
- [ ] `NSCameraUsageDescription` in Info.plist
- [ ] MetricKit integration for on-device diagnostics
- [ ] Performance profiling: cold launch <2s, queue build <1s, search <500ms
- [ ] Manual testing checklist (from PRD §11)
- [ ] App Store privacy manifest
- [ ] TestFlight build

---

## Unit & integration tests

- [ ] `SchedulerServiceTests` — SM-2 reference values
- [ ] `SchedulerServiceTests` — FSRS reference values
- [ ] `SearchServiceTests` — query parser round-trips
- [ ] `SearchServiceTests` — predicate matching fixture cards
- [ ] `MediaServiceTests` — save/load/delete + checksum
- [ ] `RenderServiceTests` — HTML snapshot tests (plain, MathJax, image, audio)
- [ ] `CloudKitSyncTests` — write/verify two-device simulation
- [ ] `LargedeckTests` — 100k card insert, query timing, queue build timing
- [ ] `StudyFlowUITests` — full session flow
- [ ] `GestureCustomisationUITests` — remap and verify
- [ ] `SearchUITests` — query → expected count
