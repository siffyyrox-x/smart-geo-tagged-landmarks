================================================================
 CSE 489 — Smart Geo-Tagged Landmarks (Lab Exam v5)
 Student: Sifat Sadakin | ID: 24341229
================================================================

----------------------------------------------------------------
1. PROJECT OVERVIEW
----------------------------------------------------------------
A Flutter (Android) app for the faculty-provided "Smart Geo-Tagged
Landmarks" REST API (https://labs.anontech.info/cse489/exm3/api.php).
Users can browse landmarks on a map and in a list, visit a landmark
(logging their GPS distance to it), add new landmarks with a photo,
soft-delete/restore their own landmarks, and review their visit
history — all of it fully usable offline, with changes syncing
automatically once the connection returns.

----------------------------------------------------------------
2. FEATURES IMPLEMENTED
----------------------------------------------------------------
- Bottom navigation with 4 tabs: Map, Landmarks, Activity, Add/View.
- Map tab: all active landmarks plotted on OpenStreetMap, centered on
  Bangladesh, marker color scaled red->green by score, tap a marker
  for a detail popup with a Visit button.
- Landmarks tab: full list with title/score/image, sortable by score
  (asc/desc), filterable by a minimum-score slider.
- Visit flow: gets a GPS fix, calls visit_landmark, receives a job_id,
  and polls get_job_status in the BACKGROUND via WorkManager (never a
  blocking UI thread loop) until the distance is ready; a Snackbar/dialog
  reports the outcome at every step.
- Activity tab: full visit history — landmark name, visit time,
  distance, and a live status (queued / syncing / done / failed).
- Add/View tab: create a landmark (title, lat/lon auto-filled from GPS
  but editable, optional camera/gallery photo sent as multipart/form-data
  as the API requires); manage your own landmarks with Delete
  (soft-delete) and Restore.
- Offline support: landmarks are cached locally (sqflite) and shown
  when there's no connection; visits made offline are queued and sent
  automatically once back online.
- Error handling: Snackbars for success/info, dialogs for hard errors
  (e.g. GPS permission denied), and the app never crashes on a bad or
  missing API field (all JSON parsing is defensive).

----------------------------------------------------------------
3. API USAGE
----------------------------------------------------------------
All network calls live in ONE place: lib/services/api_service.dart.
Every request appends ?key=24341229 (lib/config.dart, kApiKey — already
filled in with your student ID, which is this course's assigned key
format). If it ever needs to change, edit kApiKey there; a wrong/missing
key makes every endpoint return HTTP 403 {"error":"invalid_or_expired_key"}.

  GET  ?action=get_landmarks               -> list of active landmarks
  POST ?action=visit_landmark   (JSON)      -> { job_id, status:"pending" }
  GET  ?action=get_job_status&job_id=...    -> poll until status="done"/"failed"
  POST ?action=create_landmark  (multipart) -> { id }  (image sent as a file
                                                 field, NOT raw JSON, per the
                                                 API's explicit warning)
  POST ?action=delete_landmark  (form)      -> { status:"deleted" }
  POST ?action=restore_landmark (form)      -> { status:"restored" }

----------------------------------------------------------------
4. OFFLINE STRATEGY
----------------------------------------------------------------
sqflite is the single local source of truth (two tables):

  landmarks_cache -> upserted every time get_landmarks succeeds. Never
                     wiped wholesale, so a landmark the user soft-deleted
                     locally stays remembered (and restorable) even
                     across app restarts, even though the server never
                     returns soft-deleted items.

  visits           -> ONE row per visit attempt, covering its entire
                     lifecycle: queuedOffline -> submitting ->
                     pendingServer -> done/failed. This single table
                     doubles as both the Activity history AND the
                     offline outbox — there's no separate "queue" data
                     structure to keep in sync with history.

When offline: get_landmarks failures fall back to the cache; new
visits are inserted with status=queuedOffline instead of being sent.
When connectivity returns (detected via connectivity_plus): a full
sync pass runs immediately (submit every queued visit, poll every
visit still waiting on a job result) AND is guaranteed to run anyway
via the periodic WorkManager task below, even if the app was closed
when the connection came back.

----------------------------------------------------------------
5. ARCHITECTURE USED
----------------------------------------------------------------
Simple layered / repository-flavored architecture (Provider for state,
not Bloc/Riverpod, to keep the codebase approachable):

  models/      -> plain Dart data classes (Landmark, VisitRecord, VisitJob)
  services/    -> ApiService (network), DatabaseService (sqflite),
                  LocationService (geolocator), SyncEngine (the actual
                  "submit queued visit" / "poll one job" logic, shared by
                  both the foreground app and the background isolate)
  workers/     -> background_worker.dart — the ONLY file that touches the
                  `workmanager` plugin; registers the periodic safety-net
                  task and the fast per-visit poll task, and is the entry
                  point WorkManager calls in its background isolate
  providers/   -> ChangeNotifiers (LandmarksProvider, ActivityProvider,
                  ConnectivityProvider) that screens watch with `context.watch`
  screens/     -> one file per tab, plus home_screen.dart (the bottom-nav
                  shell)
  widgets/     -> small reusable pieces (LandmarkCard, ScoreBadge,
                  LandmarkImage, OfflineBanner)

Requirement 10 (Background Job Queue) explicitly calls out that polling
a visit job AND draining the offline queue are "the same underlying
problem" — this project solves both with ONE mechanism: WorkManager.
A fast one-off task (registered right after visit_landmark succeeds)
polls that specific job every ~10s (WorkManager's own backoff, no manual
Timer/Thread) until it resolves; a periodic task every 15 minutes
(Android's WorkManager minimum) is the guaranteed fallback that catches
anything missed — offline visits still unsent, or jobs still pending —
even after the app was killed and relaunched.

----------------------------------------------------------------
6. SETUP / HOW TO RUN
----------------------------------------------------------------
1. Unzip this project and open the folder in a terminal.
2. Run:                         flutter create .
   (This safely generates the android/ and ios/ native scaffolding for
   YOUR installed Flutter SDK version — it will NOT overwrite pubspec.yaml
   or the lib/ folder that's already here.)
3. Open android/app/src/main/AndroidManifest.xml and paste in the
   permissions from android_setup/AndroidManifest_additions.xml (see
   that file for exact instructions - one copy/paste, nothing else).
4. Confirm lib/config.dart's kApiKey is correct (it's pre-filled with
   24341229).
5. Run:                         flutter pub get
6. Plug in a device/emulator and run: flutter run
   (Grant location + camera/photos permission when prompted.)

TROUBLESHOOTING
- "MissingPluginException" right after a hot reload -> do a full stop
  and `flutter run` again (plugins need a fresh build, not just reload).
- Map tiles not loading -> check internet permission was added and the
  device/emulator actually has internet access.
- "Waited X seconds for a GPS fix" / location errors on an emulator ->
  set a mock location in the emulator's Extended Controls > Location.
- If flutter pub get reports a version conflict, run
  `flutter pub upgrade --major-versions` once, then re-test.
- This project was authored and reviewed WITHOUT a Flutter compiler
  available (sandboxed dev environment), so `flutter pub get` /
  `flutter run` is the first real compile it will ever go through -
  read any error message carefully; most likely causes are a package
  API drifting slightly from the version pinned in pubspec.yaml (check
  that package's pub.dev page for its current API if so) or an Android
  Gradle/AGP version mismatch (run `flutter doctor` for guidance).

----------------------------------------------------------------
7. CHALLENGES FACED
----------------------------------------------------------------
- The API's visit flow is asynchronous (job_id + polling) rather than a
  normal request/response, and the exam explicitly forbids a manual
  Thread/Timer poll loop — solving that with WorkManager while still
  giving the user a fast-feeling result took some thought (solved with
  a one-off task using WorkManager's own backoff policy instead of a
  custom loop).
- Making one data model (VisitRecord) serve three roles at once (visit
  history, offline outbox, and job-tracking) instead of three separate
  tables, so the Activity screen and the sync engine can never disagree
  about a visit's state.
- Marker color had to be relative (min/max of the currently loaded
  landmarks) rather than fixed thresholds, since the exam states the
  scoring formula varies per student key.
- [Add your own real notes here once you've actually run it on your
  key/device — what broke, what you had to tweak, etc. A genuine
  "challenges faced" section is expected to reflect your own testing.]

----------------------------------------------------------------
8. SUBMISSION CHECKLIST (from the exam sheet)
----------------------------------------------------------------
[ ] Private GitHub repo created
[ ] Instructor added as collaborator (GitHub handle: rahman9909)
[ ] project-root/app/        <- this Flutter project, WITHOUT the build/ folder
      (make sure you've run `flutter create .` and committed the
      generated android/ folder it creates - it's part of "your
      application codebase" per the exam sheet, and isn't in this zip
      yet since it has to match YOUR installed Flutter SDK version)
[ ] project-root/Ai_usage.txt
[ ] project-root/README.txt  <- this file
[ ] Tested against your real API key on a real device/emulator
[ ] Submitted via the form BEFORE 15 August 2026 midnight (Dhaka time)
    — only ONE submission is allowed, so double-check before sending.
