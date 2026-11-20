# Mobile email integration and legacy demos

## Active email flows

- Registration uses `/auth/register` and displays the backend verification-email message.
- Profile shows the current verified state, requests `/auth/resend-verification`, and refreshes `/users/me`.
- Forgot your password calls `/auth/forgot-password`; its localized acknowledgement does not reveal whether an account exists.
- Open BiletFlow link accepts signed `/verify-email?token=...` and `/reset-password?token=...` URLs. Native `biletflow://open/...` paths use the same screen. Verification requires explicit confirmation. Reset validates 8–128 characters and matching confirmation, calls `/auth/reset-password`, clears the password fields and signs out the old session after success.
- A confirmed order offers Request ticket email via `/orders/{id}/resend-confirmation`. In-flight and successful duplicate taps are disabled. Errors retain the action for retry. A successful request does not prove actual mailbox delivery.
- Preview email remains local. It displays current order information but does not send a message or manufacture PDF files. Actual ticket export uses the authenticated backend PDF endpoint.

No SMTP credentials belong in Flutter. Configure delivery on the backend. Automatic
opening of hosted HTTPS email links in the app requires deployment-domain association;
users can also paste an existing email link into Open BiletFlow link. Never enter a
signed token into the old six-digit-code demo.

## Legacy isolated demos

`EmailAuthScreen` and `DemoEmailFlow` remain available for existing tests and explicit
UI demonstrations. They use code `123456`, local cooldown/expiry/attempt limits, and
clearly labeled previews. They do not change verification or passwords and are no
longer the production sign-in/profile recovery path. They are not interchangeable
with the backend's signed tokens.

## Validation

`test/demo_email_flows_test.dart` verifies that the isolated code demos and preview
make no API requests, while the real ticket email action calls the resend endpoint.
`test/mobile_completion_flows_test.dart` covers email retry/duplicate prevention,
verification confirmation, expired tokens and password-reset completion.
The opt-in `test/live_backend_contract_test.dart` checks the actual API with a
disposable database and an in-memory mailbox. SMTP receipt must be tested separately.
