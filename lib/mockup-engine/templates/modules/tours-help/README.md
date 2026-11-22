# tours-help: the help centre and guided tours

Page: `help` (`/help`, any signed-in user). Components: `TourList`, `ShortcutList`.

Files: `assets/tours.js`, `assets/tours.css`, `data/help.js` (the tours and the support contact),
and `assets/vendor/driver.js.iife.js` with `driver.css`: driver.js 1.9.0, MIT, its licence in
`assets/vendor/driver.js.LICENSE`. Fixtures: `tours_seen`. Screens: 2.

Every page that can start a tour loads `driver.css`, `tours.css`, `data/help.js`,
`driver.js.iife.js` and `tours.js`, as `pages/help.html` does. The sample tours in `data/help.js`
name routes and `data-tour` anchors of the example's pages: rewrite them for the mockup's pages,
or the inventory reports each missing route and anchor (`tour-route`, `tour-anchor`).

Shell: a Help link to `./help.html` in the header.
