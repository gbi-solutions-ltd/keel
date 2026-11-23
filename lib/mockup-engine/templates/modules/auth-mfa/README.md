# auth-mfa: sign in with a second step

Pages: `sign-in` (`/sign-in`), `sign-in-verify` (`/sign-in/verify`), `security` (`/account/security`),
`security-authenticator` (`/account/security/authenticator`). The sign-in pages are public and use
`AuthLayout`; the security pages need a signed-in user.

Components: `AuthLayout`, `Dialog`, `FactorRow`, `Notice`, `OneTimeCodeField`, `RadioGroup`,
`RecoveryCodes`, `StepUpDialog`, `Stepper`. Fixtures: `auth` (the challenge, the factors, masked
destinations, the authenticator enrolment). Screens: 18.

Permissions: none beyond signed in. Shell: a link to `./security.html` where the account's links
are (the `notifications` module's account menu carries one); `AuthLayout` shows the product's
name in `.auth-layout__brand`: put the client's there.
