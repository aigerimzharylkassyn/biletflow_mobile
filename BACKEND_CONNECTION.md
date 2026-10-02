# Backend connection

The app now uses the FastAPI backend, with bearer authentication and backend-provided roles.
The previous mock accounts and mock events are no longer used. Register a real attendee
account (password: at least 8 characters), or use an existing backend account.
Organizer and administrator roles must be provisioned on the backend; the app cannot grant roles.
Sessions are kept in memory; sign in again after restarting the app or when the token expires.

From the `biletflow_mobile` project directory:

```sh
flutter pub get
flutter run
```

Defaults: iOS Simulator uses `http://127.0.0.1:8000/api/v1`; Android Emulator uses
`http://10.0.2.2:8000/api/v1`.

For a physical phone, connect it to the same Wi-Fi as the backend computer. Start the backend with
`uv run uvicorn app.main:app --host 0.0.0.0 --port 8000`, and set the computer's LAN IP:

```sh
flutter run --dart-define=API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:8000/api/v1
```

Local HTTP is intended for development. Use an HTTPS backend for release builds.
Android debug builds allow local HTTP. iOS permits local networking and asks for LAN access.

Connected flows: register/login/logout, role routing, events, ticket-type selection,
checkout with a total including fees, simulated payment, owned tickets with real QR images,
organizer event creation and revenue/registrations, manual credential check-in, admin users/events
and suspension. Cancelling checkout releases the reserved inventory via the backend's failed
payment simulation. Event creation currently uses 18:00–22:00 and capacity 100, shown in the form.
Paid ticket sales require organizer verification and paid-sales activation through the backend API.

Check-in accepts the full signed credential shown in ticket details; camera scanning is not
implemented. Profile edit, notification settings, FAQ and contact links retain their existing
Coming Soon behavior. The API has no user-reactivation endpoint, so suspended-user buttons are disabled.
The backend starts empty. For an end-to-end local check, run
`uv run python -m app.dev_seed` once. It idempotently creates multiple events,
venues, ticket types, attendees, registrations, revenue, ticket history, and all
four application roles. The command prints the primary account addresses and all
use `DemoPass123!`. The app maps assigned `event_admin` users to its staff-only
Check-in and Profile navigation.

Validation: `dart analyze lib test` and `flutter test`.
