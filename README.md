# BiletFlow — Flutter app

Self-service event ticketing app with attendee, organizer, and administrator
screens. The app connects to a FastAPI backend for authentication, events,
tickets, checkout, and administration. Payments are currently simulated.

This folder contains the Flutter client only. The FastAPI server and its database
must be set up separately; uploading the client to GitHub does not host the backend.

## Setup

Requires Flutter 3.27 or later with Dart 3.6 or later, plus the platform tools for
your target device. Android, iOS, and web platform folders are included.

From the `biletflow_mobile` project directory:

```sh
flutter pub get
flutter gen-l10n
flutter run
```

Start the separately configured backend before using the app. From the backend
project directory, with its dependencies and database configured:

```sh
uv sync --all-extras --python 3.13
uv run python -m app.dev_seed   # optional, creates rich demo data for every role
uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
```

The app's default API addresses are:

| Target | API base URL |
|---|---|
| Android Emulator | `http://10.0.2.2:8000/api/v1` |
| iOS Simulator | `http://127.0.0.1:8000/api/v1` |

For a physical phone, connect it to the same Wi-Fi as the backend computer and
replace `YOUR_COMPUTER_LAN_IP` with that computer's LAN IP:

```sh
flutter run --dart-define=API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:8000/api/v1
```

For a hosted backend, set `API_BASE_URL` to its HTTPS address, including `/api/v1`,
when running or building the app. Local HTTP is intended for development.
See [Backend connection](BACKEND_CONNECTION.md) for further integration details.

## Accounts and roles

Register a real attendee account with a password of at least eight characters,
or sign in with an existing backend account. Organizer and administrator roles
must be provisioned on the backend. For local checks, the optional backend seed
also creates events, users, registrations, revenue, and attendee tickets. It
creates `attendee.demo@example.com`, `organizer.demo@example.com`,
`staff.demo@example.com`, and `admin.demo@example.com`; each uses
`DemoPass123!`.

Sessions are held in memory. Sign in again after restarting the app or when the
token expires.

## Features

- Attendees: browse events, select ticket types, check out with simulated payment,
  and view owned tickets with QR images.
- Organizers: create events, view registrations and revenue, and check in attendees
  by entering their full signed ticket credential.
- Check-in staff: view assigned events and admit attendees.
- Administrators: view users and events, and suspend users.

## Android Studio

Open this `biletflow_mobile` directory (not only its `android` subdirectory) in
Android Studio with the Flutter and Dart plugins enabled. Run `flutter pub get`,
select an Android emulator, and run `lib/main.dart`. The standard Android emulator
uses the default `10.0.2.2` alias to reach the backend on the development computer.
Do not replace it with `localhost`, which points back to the emulator itself.

The debug manifest permits local HTTP for development. Confirm the server first at
`http://127.0.0.1:8000/api/v1/health`; hosted/release builds should use an HTTPS
`API_BASE_URL`.

## Languages

The default language is Kazakh (Latin script), with Russian and English also
available. Switch languages from the login screen or Profile → Language.
The preference persists across restarts.

Translations are in `lib/l10n/app_kk.arb`, `app_ru.arb`, and `app_en.arb`.
Run `flutter gen-l10n` after editing them; generated files in `lib/l10n/gen/`
are excluded from Git. Kazakh translations still need native-speaker review.

## Project structure

- `lib/services/api_client.dart` — API URL configuration, HTTP requests, and bearer authentication.
- `lib/services/auth_service.dart` — registration, login, and session state.
- `lib/services/data_service.dart` — backend events, tickets, checkout, and role-specific actions.
- `lib/features/` — authentication, attendee, organizer, administrator, and profile screens.
- `lib/shared/widgets/` — reusable UI components.
- `lib/app/` — app configuration, routes, and theme.
- `test/api_integration_test.dart` — client authentication tests using mocked HTTP responses.

## Validation

```sh
dart analyze lib test
flutter test
```

The automated tests use mocked server responses. They do not verify a running
FastAPI server; exercise the app against your backend to validate the full flows.

## Current limitations

- Payment completion is simulated; real payment processing is not integrated.
- Paid sales require organizer verification and paid-sales activation on the backend.
- Camera scanning is not implemented; check-in uses manual credential entry.
- Event creation currently uses 18:00–22:00 and a capacity of 100.
- Profile editing, notification settings, FAQ, and contact links show Coming Soon.
- Suspended accounts cannot be reactivated through the app because the API has no
  reactivation endpoint.

## Version control

Commit source code, platform project files, and `pubspec.lock`. Generated build
files, local environment files, and signing credentials should stay out of Git.
If configuration examples are needed, use `.env.example` with placeholder values.
The app reads `API_BASE_URL` through `--dart-define`; it does not load `.env` files.
