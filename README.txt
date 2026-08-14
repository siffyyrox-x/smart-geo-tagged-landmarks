1. PROJECT OVERVIEW

A Flutter Android app using the provided Smart Geo-Tagged Landmarks API.

Users can view landmarks on a map and list.

They can visit landmarks using GPS and check the distance.

They can add landmarks with photos.

They can delete and restore their own landmarks.

They can also see their visit history.

The app works offline and syncs automatically when the internet returns. 

2. FEATURES IMPLEMENTED

The app has 4 tabs: Map, Landmarks, Activity, and Add/View.

The Map shows all active landmarks on OpenStreetMap.

Markers change from red to green based on the score.

Users can tap a marker to see its details and visit it.

The Landmarks tab shows the title, score, and image.

Users can sort and filter the landmarks.

The Visit feature gets the user's GPS location and calculates the distance.

The result is checked in the background using WorkManager.

The Activity tab shows visit time, distance, and status.

Users can add landmarks with GPS coordinates and photos.

Users can delete or restore their own landmarks.

Landmarks are saved locally for offline use.

Offline visits are saved and sent when the internet returns.

The app shows errors clearly and handles missing API data safely. 

3. API USAGE

All API requests are handled in `api_service.dart`.

The API key is stored in `config.dart`.

`get_landmarks` gets the active landmarks.

`visit_landmark` starts a visit.

`get_job_status` checks the visit result.

`create_landmark` creates a landmark with a photo.

`delete_landmark` deletes a landmark.

`restore_landmark` restores a landmark. 

4. OFFLINE STRATEGY

The app uses sqflite for local storage.

`landmarks_cache` stores landmark data for offline use.

`visits` stores every visit and its status.

When offline, landmarks are loaded from the cache.

Offline visits are saved instead of being sent.

When the internet returns, saved visits are sent automatically.

WorkManager also runs a backup sync process. 

5. ARCHITECTURE USED

The app uses a simple layered architecture with Provider.

`models/` contains the data classes.

`services/` handles the API, database, GPS, and syncing.

`workers/` handles background WorkManager tasks.

`providers/` manages app state.

`screens/` contains the app screens.

`widgets/` contains reusable UI components. 

WorkManager handles both pending visits and offline syncing.

It checks individual jobs about every 10 seconds.

A 15-minute backup task handles missed jobs. 

6. SETUP / HOW TO RUN

1. Open the project folder.
2. Run `flutter create .`
3. Add the required Android permissions.
4. Check the API key in `config.dart`.
5. Run `flutter pub get`.
6. Connect a device or emulator.
7. Run `flutter run`.
8. Allow location and camera permissions. 


Submit before **15 August 2026, midnight Dhaka time**.

Only one submission is allowed. 
