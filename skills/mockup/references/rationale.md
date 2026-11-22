# Why the mockup skill works the way it does

Read this before changing a step. Each entry is the reason for one instruction in this skill's
`SKILL.md`, and where one exists, the failure that produced it.

## The mockup is the specification

A client signs off on what they saw. If the app differs, either the client is surprised at launch or
the team argues about what was approved. Treating the mockup as the specification makes "done"
checkable, and makes every unspecified thing visible as a gap rather than silently decided by
whoever wrote the code.

## Plain HTML, but framework shaped

Mocking directly in the target stack fails three ways: the stack is often unknown at mock time, a
framework mockup is heavier to share than a folder that opens from disk, and a client who sees
something that looks real assumes it is nearly finished. Plain HTML avoids all three. Unstructured
HTML is what makes conversion hard, so the conventions (`mk.js`, pure components, fixtures, page
definitions with state and actions) give it the shape a framework will need, and conversion becomes
translation rather than reverse engineering.

## Check the mockup before the client sees it

A defect in the design (low contrast, a page that scrolls sideways on a phone, a control with no
focus indicator) costs one file to fix in the mockup. After conversion it costs the mockup, the
app, and a second sign-off, because the client approved the defect. The same quality check runs on
both sides for this reason. It is also the contrast check: axe's `color-contrast` rule in
`quality-check.mjs` measures every screen, state and viewport, so there is no separate contrast
script to run or keep in step.

## Every role is designed and compared

Most client apps have more than one kind of user, and the role that sees least is the one nobody
looked at. Previewing roles in the mockup puts that decision in front of the client; listing screens
per role makes the visual diff check it; the role matrix makes it a document they approve.

## Interaction steps in the screen list

A sorted table, an open menu and a palette with results are states the client signs off as surely
as a page load, and they are where a port most often differs: the first run of these steps found a
table scroll position, a column's alignment and a palette colour that page loads alone would have
missed.

## Modules, and a checklist decided with the client

Sign-in with a second factor, page tours, user management, an audit log, password reset and
session timeouts, notifications and the pages for failure were asked for in nearly every app and
built differently each time, so they are designed once, proven in React by the same visual diff,
and copied in. Each was proven before the next stack is tried, because a module proven in one stack
is a specification; one written for three at once is a guess.
Everything else a client forgets (an audit log, a session timeout, user management) is a question
rather than a design, so the checklist asks it before sign-off. The inventory lists every item
still undecided; `inventory --ready-to-port` refuses a mockup with any left. A `later` answer is still an answer: it lands in the gap report instead of in a
surprised go-live meeting.

## No identity provider assumed

The browser talks only to the app's own API, which owns the session cookie. That keeps tokens out
of script, and it means the screens and the contract survive the choice of provider (or of none)
unchanged. A UI built against one provider's hosted pages would be rebuilt when the provider
changes, and would not match the client's signed-off design anyway. When the app has no sign-in
screen, the backend is the OpenID Connect client (a confidential one, with PKCE), not the browser:
the tokens stay on the server, and the provider can change behind `userFromClaims` alone.

## Tours start once, on a large enough screen, and are recorded by the server

A tour that starts on every visit is closed unread; one recorded only in the browser starts again
on every device. On a phone the popover covers the page it explains, so it waits for the help
centre there. Steps whose controls a role cannot see are skipped rather than written per role,
because a tour per role drifts out of date one role at a time.

## The design framework is decided before the first screen

A client's stack is a framework plus how it is styled and built from parts, and the parts change how
the mockup should be built: a mockup in its own CSS for a client with a design system is signed off on
a look the app will not have, and a port of it needs a second pass over every page. The one port that
learned this did the second pass (every page, then a cleanup removing most of the port's own
components and CSS); it worked, and it was the cost of finding the framework late. So the intake asks
for it, the mockup is built in it where a plain HTML page can be (CSS frameworks and design systems
shipped as CSS), and only a JS component kit is approximated, with the client told that sign-off is on
an approximation and the port gated by a declared tolerance and the behaviours. Pixel port first,
adopt after, stays as the route for a framework that arrives after sign-off.
