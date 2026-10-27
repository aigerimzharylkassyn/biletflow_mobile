# Email UI demo and backend handoff

This implementation changes only `biletflow_mobile`. It does not send email,
change credentials, change `email_verified`, or call verification/recovery/email
endpoints. Existing registration, login, checkout and PDF downloads still use the
existing API and have not been replaced by fake accounts or orders.

## Try the demo

- Sign in screen → Forgot your password → enter any syntactically valid email.
- After registering, the verification preview opens; Skip lets you continue.
- Profile → Try email verification reopens the verification preview.
- Enter demo code **123456**. A code expires after 15 minutes, can be used once,
  and locks after five incorrect attempts. Request another after 60 seconds.
- Password reset validates 8–128 characters and matching confirmation. The sample
  password is cleared on success and is never passed to the simulator or an API.
  Continue signing in with the original real password.
- Open a confirmed, non-cancelled order with valid/checked-in tickets. Ticket email
  → Preview email shows recipient, event, attendee, total, order and attachment
  names from that order. Simulate sending changes only the local demo message.
  The PDF names are previews; actual PDF downloads remain in the ticket section.

All demo states are local to the screen and reset when it is closed. There is no
SMTP server, inbox process, persisted demo verification flag, or stored password.
Labels and feedback are localized in English, Russian and Kazakh Cyrillic.

## Integration points

- `lib/services/demo_email_flow.dart`: isolated code/expiry/cooldown simulator;
  `EmailAuthScreen.demo` permits injecting it in tests. Replace it with an API
  adapter once the contract is agreed. Server-side expiry, attempt limits and
  single-use checks must be authoritative; these current checks are a UI demo.
- `lib/features/auth/email_auth_screen.dart`: email/code entry, sample password
  validation, resend, errors and explicit demo success screens. Integrate returned
  user state only after the server confirms real verification. Integrate real
  credential changes only after server confirmation.
- `lib/features/attendee/ticket_email_panel.dart`: local confirmation preview and
  simulated delivery; connect actual delivery/status/resend to server-confirmed
  outcomes. Never treat pressing Send as proof of delivery.
- Registration and Profile launch the verification preview. Sign in launches
  recovery. Order details conditionally includes the confirmation preview.

The current backend uses signed `token` payloads for `/auth/verify-email` and
`/auth/reset-password`, and demo response headers to expose those tokens. This UI
uses a six-digit demonstration code, not those signed tokens. Do not simply post
`123456` to the existing endpoints. Agree whether production uses code exchange or
emailed links/tokens before replacing the simulator. SMTP credentials and email
sending belong on the backend, never inside Flutter.

## Validation

`flutter analyze --no-pub`

`flutter test --no-pub`

The dedicated tests verify that demo verification, password reset and email
preview/sending produce zero backend requests. Responsive tests cover the new
screens, reset code-entry step and confirmation sheet in all three locales.
