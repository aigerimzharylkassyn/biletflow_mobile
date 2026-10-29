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
checkout with server-priced totals, simulated payment, owned tickets with real QR images,
organizer event creation and revenue/registrations, camera QR check-in, admin users/events
and suspension. Event creation currently uses 18:00–22:00 and capacity 100, shown in the form.
Paid ticket sales require organizer verification and paid-sales activation through the backend API.

Account emails:
- Registration sends a verification email; the app shows where it was sent. The Profile screen
  shows whether the email is verified, can resend the link (`POST /auth/resend-verification`)
  and refresh the status (`GET /users/me`). Organizers must verify before publishing events.
- "Forgot your password?" on the login screen calls `POST /auth/forgot-password`. The emailed
  link opens the web app's `/reset-password` page, where the new password is chosen.

Checkout and promo codes:
- After choosing a ticket, the attendee can enter a promo code. Totals come from
  `POST /promo-codes/validate` (subtotal, discount with code, processing fee, total); the
  backend's rejection message (expired, exhausted, disabled, not applicable…) is shown as-is.
- The code is passed to `POST /checkout/sessions`. Backing out calls
  `POST /checkout/sessions/{id}/cancel`, which releases the reserved ticket immediately.
- After confirmation the app tells the attendee that the tickets were also emailed.

Check-in (staff, organizers):
- The camera scans ticket QR codes (`mobile_scanner`). Each scan calls
  `POST /check-in/events/{id}/validate` and shows a full-width result with colour, icon and
  text: valid, already used, cancelled, refunded, wrong event or invalid. Campaign (promo) QR
  codes are rejected with the backend message "This is a promotional Campaign QR code, not an
  admission ticket."
- Valid tickets are admitted only after tapping Admit (`/admit`). Undo reverses the check-in
  (`POST /check-in/records/{record_id}/reverse`). Registered/checked-in counts come from
  `/check-in/events/{id}/summary` and refresh after each admission.
- The same code is ignored for 3 seconds after a result is dismissed, so a ticket left in view
  is not re-scanned. If camera permission is denied or no camera exists, the manual
  credential field remains available.
- Android requests the `CAMERA` permission; iOS uses `NSCameraUsageDescription`.

Profile edit, notification settings, FAQ and contact links retain their existing
Coming Soon behavior. The API has no user-reactivation endpoint, so suspended-user buttons are disabled.
The backend starts empty. For an end-to-end local check, run
`uv run python -m app.dev_seed` once. It idempotently creates multiple events,
venues, ticket types, attendees, registrations, revenue, ticket history, and all
four application roles. The command prints the primary account addresses and all
use `DemoPass123!`. The app maps assigned `event_admin` users to its staff-only
Check-in and Profile navigation.

Validation: `dart analyze lib test` and `flutter test`.
