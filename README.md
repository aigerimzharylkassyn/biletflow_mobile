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

Attendees can apply through Profile → Become an organizer. Administrators review
pending requests through Dashboard → Organizer applications. Approval grants the
organizer role; applicants refresh their status to open the organizer dashboard.

## Features

- Attendees: browse events, select ticket types, check out with simulated payment,
  and view owned tickets with QR images.
- Organizers: create events, view registrations and revenue, and check in attendees
  by scanning their ticket QR code or entering their signed credential.
- Check-in staff: Events, Check-in and Profile tabs, assigned events sorted by start time with All / Upcoming / Live / Past / Cancelled filters, attendance statistics, searchable ticket rosters, manual admission and check-in reversal.
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

The default language is Kazakh (Cyrillic script), with Russian and English also
available. Switch languages from the login screen or Profile → Language.
The preference persists across restarts.

Interface text uses bundled Noto Sans in regular, medium, semibold, and bold
weights, with Latin and Kazakh/Russian Cyrillic glyphs in each file. Font files
and their SIL Open Font License are in `assets/fonts/noto_sans/`. The source is
[the Noto fonts repository](https://github.com/notofonts/noto-fonts/tree/main/hinted/ttf/NotoSans).

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

## Attendee mobile experience

The attendee UI follows the flows in the sibling `biletflow_web` project:

- Search public events by title, venue, address or city, with category filters,
  refresh, loading/error feedback and empty states.
- View event images, local date/time, venue/map, host, refund policy and a shareable
  calendar file. Select multiple ticket types/quantities within inventory and
  per-order limits; apply a promo code.
- Enter attendee details, reserve tickets, review backend fees/discounts and the
  countdown, confirm a simulated payment, or explicitly cancel a reservation.
- Browse upcoming/past tickets and order history. Booking pages show money/status,
  per-ticket QR/status, seats where supplied, calendar sharing and authenticated
  PDF ticket export. Refunded/cancelled tickets have no admission QR.
- Edit profile, read/mark notifications, browse FAQ, and create/reply to support
  requests. Support launched from a booking includes its order/event context.

Run `flutter pub get` and fully restart/rebuild the app after these changes;
PDF/calendar sharing and maps use native plugins. Test the native share sheet,
calendar import, PDF export and map handoff on a physical device.

## Validation

```sh
dart analyze lib test
flutter test
```

The automated tests use mocked server responses. They do not verify a running
FastAPI server; exercise the app against your backend to validate the full flows.

## Current limitations

- Payment completion is simulated; real payment processing is not integrated.
- Paid events require a completed activation checklist and manual Platform Admin approval before publication and paid checkout.
- Paid events require a written refund policy; it is optional for free events.
- Attendees can request a full-order refund or contact the organizer from their tickets.
  The organizer inbox supports search and status, event and category filters.
  Approval completes a simulated refund, invalidates all order tickets, notifies the
  attendee and solves the linked refund case in both views. Ticket-scanning permissions do not grant support. Explicit support staff can handle
  scoped cases but cannot issue refunds. Real payment-provider refunds are not integrated.
- Camera scanning, manual credential entry and attendee search are available for check-in.
  Organizers and assigned staff can admit a valid ticket or reverse an active check-in.
  Attendance statistics count valid and checked-in tickets, excluding cancelled/refunded tickets.
  The backend must include `GET /check-in/events/{event_id}/attendees` and
  `POST /check-in/events/{event_id}/tickets/{ticket_id}/admit`.
- Ticket QR codes are rendered locally from server-issued credentials; no extra
  image request is needed. Camera scanning should be tested on a physical phone.
- Organizer creation uses a three-step wizard matching the web: custom event and
  registration dates in UTC+05:00, venue, capacity, visibility, banner URL, refund
  policy, multiple free/paid ticket types, review and sandbox paid-sales activation.
  Choose Free event (the default) for zero-price tickets without paid activation,
  or Paid / mixed tickets to configure paid admission. Saved drafts can be reopened
  from My Events; saved ticket types are read-only.
- Official terms/privacy documents have not been supplied; their screens explain
  how to request the current official documents through support.
- The local backend currently lacks standalone promo quotes. Promo codes are
  validated during reservation when quoting returns 404/405. Ticket responses now
  include order IDs so booking details can display the correct tickets.
- Checkout sends stable Idempotency-Key headers on retries, but duplicate-request
  guarantees require backend enforcement of those keys.
- Suspended accounts cannot be reactivated through the app because the API has no
  reactivation endpoint.

## Version control

Commit source code, platform project files, and `pubspec.lock`. Generated build
files, local environment files, and signing credentials should stay out of Git.
If configuration examples are needed, use `.env.example` with placeholder values.
The app reads `API_BASE_URL` through `--dart-define`; it does not load `.env` files.

## Support queues

Attendee support and platform support are separate queues. Organizer and staff
Inbox tabs contain attendee cases only. Contact Platform Admin is available from
their Profile pages; admins have a distinct platform inbox.
Organizers grant event support access through Authorize support staff, then assign
a case using its assignee selector. Staff inboxes show their assigned cases and
refresh every 30 seconds while active, including refreshed support permissions.
Staff can contact Platform Admin without attendee-support permission.
Customers can view their own conversations, while handlers filter and assign cases
within their authorized scope. Profile refresh/sign-in reloads granted capabilities.
Attendee New chat requires an explicit destination: an event/owned booking routes
its context to the event organizer; General app/account help routes to Platform Admin.
The admin platform inbox includes general attendee requests alongside organizer/staff
platform cases. Event-specific attendee cases remain in organizer/staff inboxes.
Case status, order status and refund execution are displayed separately.

The backend includes an additive support-schema migration and API documentation in
`biletflow/docs/SUPPORT_FLOWS.md`. Notifications are in-app; email delivery is not
implemented. Support screens poll while active and stop in inactive tabs/background.

### Sample support conversations

The local demo accounts each use `DemoPass123!`. From the backend directory, run
`python -m app.dev_support_seed` (using its virtual environment) to add these
samples. Run `python -m app.dev_seed` first only if demo accounts are missing.
The support seed preserves existing conversations and adds no duplicates on reruns.

| Sign in as | Where to open | Sample conversations |
|---|---|---|
| `attendee.demo@example.com` | Profile → Contact Us | Refund review (Open), missing ticket email (In Progress), accessible entrance (Waiting for Customer), ticket download (Resolved) |
| `organizer.demo@example.com` | Inbox | All four attendee cases; open a case to reply, assign staff, or update status |
| `staff.demo@example.com` | Inbox | Three assigned cases: ticket email, accessible entrance, and resolved download |
| `organizer.demo@example.com` | Profile → Contact Platform Admin | Demonstration payment report question |
| `staff.demo@example.com` | Profile → Contact Platform Admin | Camera permission help |
| `admin.demo@example.com` | Platform support inbox | Organizer payment and staff camera conversations |

All sample subjects begin with `[Demo]`. The support seed grants the demo staff
member support access for the linked event, preserving existing permissions.
It does not execute refunds or change ticket/payment states. To try assignment,
open the refund case as organizer and assign Demo Check-in Staff. Sign in as staff
and open Inbox; the active inbox refreshes within 30 seconds, or tap Refresh.
Reply as staff, then sign in as attendee and open the same conversation.

### Event cancellation

Organizer cancellation stops sales, cancels unused tickets, and creates one in-app
cancellation notification per attendee. Check-in and ticket admission exports are
blocked for cancelled events, including older tickets whose saved status is valid.
Checked-in/refunded records are retained. Reversing an earlier check-in on a
cancelled event leaves its ticket cancelled. Pending checkout cannot issue tickets
after cancellation. Cancellation does not execute refunds: paid orders remain
available for a separate full refund through orders or refund support cases.

### Paid event applications and admin navigation

Organizers complete event details and tickets, record the simulated activation fee,
and submit for review. The event stays in draft with publishing disabled until a
Platform Admin approves it. Rejection includes a reason; corrections can be
resubmitted without paying the fee again. Material changes require a new review.
Approval and rejection generate in-app notifications; approval does not publish.

Admin navigation is Dashboard / Applications / Events / Inbox / Profile.
Applications contains paid-event reviews; user management and organizer-role
applications are available through Dashboard buttons. Events has lifecycle and
category filters, organizer/title search, and global database statistics.
Existing events can be moved back to draft through Edit event before resubmission.
Previously unreviewed paid events must complete review before new paid checkout.

### Sample paid-event applications

Sign in as `admin.demo@example.com` and open Applications. Five `[Demo]` samples
are available: Evening Jazz and Tech Forum (awaiting review), Food and Craft
Market (approved, still a draft), Stand-up Comedy Night (rejected with a reason),
and Contemporary Art Workshop (changes require review).

Use `paid.organizer.demo@example.com` to inspect the organizer side and try
publishing or resubmitting these drafts. Both demo accounts use `DemoPass123!`.
The dedicated organizer has simulated profile/payout data and recorded demo fees;
no real payment or verification is involved. Existing account passwords are preserved.

To add these samples to another local backend database, run
`python -m app.dev_paid_event_seed` in the backend environment. Repeated runs
preserve decisions and edits instead of duplicating or resetting applications.

### Finding paid-event review decisions

My Events displays the paid-review state on draft cards: Awaiting review,
Approved / ready to publish, Rejected, Needs resubmission, or Not submitted.
Opening a submitted draft takes the organizer directly to the Review step.
Publishing remains disabled until the current backend checklist confirms approval.

Profile → Notifications includes Open event for paid-event review decisions.
The link checks the event's current state: drafts open at Review, while published
or cancelled events open their details. Missing/inaccessible events show an error;
opening a notification never publishes or resubmits an event automatically.

## Email UI demos

Verification, password recovery, confirmation-email previews, and simulated ticket
email delivery are available as **frontend-only demos**. Use code `123456` in the
verification/reset screens. No email is sent and no real password or verification
status changes. Existing account registration, login, booking and ticket PDF
features continue to use the backend normally.

Open Forgot your password, Profile → Try email verification, or a confirmed
order's Ticket email section. For integration boundaries and backend handoff, see
[Email UI demo](docs/EMAIL_DEMO_HANDOFF.md).


## Event management and operations

Organizer Dashboard → Analytics opens the event workspace. The event selector
switches between managed events. Analytics uses database orders, tickets and
refunds, with order-date (UTC) and ticket-type filters, current inventory,
attendance, daily sales, ticket comparisons and campaign attribution. Financial
figures remain simulated; net revenue includes processing fees and subtracts
completed refunds once. Date filters select order cohorts, not refund posting dates.

Event details → Event workspace provides Orders & registrations and Activity
history. Organizer and administrator order actions require a reason: full paid
refunds invalidate all order tickets; cancellation of a confirmed free registration
invalidates its tickets and releases inventory. Checked-in free registrations must
have admission reversed first. Staff cannot perform these financial/order actions;
their attendance page links to read-only event activity. New support changes and
checkout outcomes also enter the audit timeline. Historical records are retained;
no timeline mutation or rollback endpoint is exposed.

Event details → Duplicate event creates a new draft with event information and
copied ticket types, without orders, tickets, staff assignments, campaigns, fees or
approvals. Update the dates before publication. Unsold copied ticket types remain
editable; sales windows outside the updated registration period are aligned with
that period. The original event and ticket types remain unchanged.

Admin Events → an event → Platform controls suspends/restores the whole event or
paid sales separately. Whole-event suspension blocks discovery, purchases and
admission without deleting existing tickets; paid-sales suspension preserves
existing admission and free registration. Restoring sales never grants an approval:
changed/unapproved events return to the review flow. The organizer receives an
in-app notification with the reason. Cancelled/completed events cannot be restored
through suspension controls.

Admin Dashboard → Operations monitor searches orders/payment references, shows
failed payments and refunds, displays configured fees and shares filtered orders
as CSV. User management supports suspension/restoration with reasons. These flows
use the backend in the sibling `biletflow` folder; restart that server after updating
its code. No new database columns are required for these management features.
The separate email screens remain frontend-only demos.
