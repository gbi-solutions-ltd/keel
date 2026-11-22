/*
 * tours.js: page tours for the mockup (the tours module). Needs vendor/driver.js.iife.js and
 * data/help.js loaded first. Becomes the app's tour hook in the layout; keep the two identical.
 *
 * A page's tour starts by itself once the page is ready, when all of these hold:
 *   - the tour's route is this page and the user holds its permission
 *   - the user has not finished this version of it (GET /v1/me/tours; here fixtures.tours_seen,
 *     plus what was finished in this tab)
 *   - the viewport is at least --breakpoint-md wide: on a phone a tour covers the page it explains
 *   - at least one of its anchors is on the page
 * ?tour=<id> starts that tour whatever the rules say (the help centre links that way) and is then
 * removed from the address. Closing a tour counts as finishing it (PUT /v1/me/tours/{id}).
 * Preview flag: ?tours=reset treats every tour as unseen, as the app's mocks do.
 */
(function () {
  'use strict';

  const KEY = 'mk:tours-seen';
  const params = new URLSearchParams(location.search);
  const help = window.HELP || { tours: [] };

  function seen() {
    if (params.get('tours') === 'reset') return {};
    let local = {};
    try { local = JSON.parse(sessionStorage.getItem(KEY) || '{}'); } catch { /* storage blocked */ }
    return { ...(window.FIXTURES?.tours_seen || {}), ...local };
  }
  function markSeen(tour) {
    try {
      const local = JSON.parse(sessionStorage.getItem(KEY) || '{}');
      local[tour.id] = tour.version;
      sessionStorage.setItem(KEY, JSON.stringify(local));
    } catch { /* storage blocked: the tour shows again next load, which is harmless here */ }
  }

  const present = (tour) => tour.steps.filter((s) => document.querySelector(`[data-tour="${s.target}"]`));
  const wide = () => matchMedia('(min-width: 48rem)').matches; // --breakpoint-md

  // driver.js marks the highlighted element as opening a dialog (aria-haspopup, aria-expanded,
  // aria-controls). On a div or section those are invalid ARIA, and on a button they misstate what
  // it does, so each element keeps its own values while highlighted.
  const ARIA = ['aria-haspopup', 'aria-expanded', 'aria-controls'];
  function keepAria(steps) {
    const saved = new Map(steps.map((s) => {
      const el = document.querySelector(`[data-tour="${s.target}"]`);
      return [el, ARIA.map((a) => el.getAttribute(a))];
    }));
    return (el) => {
      const values = saved.get(el);
      if (values) ARIA.forEach((a, i) => (values[i] === null ? el.removeAttribute(a) : el.setAttribute(a, values[i])));
    };
  }

  // The driver.js options. The app's lib/tours.ts passes exactly these.
  function start(tour) {
    const steps = present(tour);
    if (!steps.length) return false;
    const restoreAria = keepAria(steps);
    const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
    const d = window.driver.js.driver({
      animate: !reduced,
      smoothScroll: !reduced,
      allowClose: true,
      overlayOpacity: 0.5,
      stagePadding: 6,
      stageRadius: 6,
      popoverClass: 'tour-popover',
      showProgress: steps.length > 1,
      progressText: '{{current}} of {{total}}',
      nextBtnText: 'Next',
      prevBtnText: 'Back',
      doneBtnText: 'Done',
      steps: steps.map((s) => ({ element: `[data-tour="${s.target}"]`, popover: { title: s.title, description: s.body } })),
      onHighlighted: (el) => restoreAria(el),
      onDestroyed: () => markSeen(tour),
    });
    d.drive();
    return true;
  }

  let ran = false;
  MK.onRender(({ page, status, session }) => {
    if (ran || status !== 'ready') return;
    const asked = params.get('tour');
    const mine = help.tours.filter((t) => t.route === page.route && session.permissions.includes(t.permission));
    const s = seen();
    const tour = asked
      ? mine.find((t) => t.id === asked)
      : wide() && mine.find((t) => (s[t.id] || 0) < t.version);
    if (!tour) return;
    ran = true;
    if (asked) {
      params.delete('tour');
      const qs = params.toString();
      history.replaceState(null, '', `${location.pathname}${qs ? `?${qs}` : ''}`);
    }
    requestAnimationFrame(() => start(tour));
  });

  MK.tours = { list: (session) => help.tours.filter((t) => session.permissions.includes(t.permission)), start };
})();
