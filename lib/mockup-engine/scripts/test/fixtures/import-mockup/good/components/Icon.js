// Icon: the icon table. Each value is the inner markup of a 24 by 24 SVG.
const ICON_PATHS = {
  check: '<path d="M5 12l5 5L20 7" fill="none" stroke="currentColor" stroke-width="2"/>',
  'chevron-down': '<path d="M6 9l6 6 6-6"/>',
  group: '<g fill="none" stroke="currentColor"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 3"/></g>',
};

MK.component('Icon', ({ name }) => MK.html`<svg viewBox="0 0 24 24" aria-hidden="true">${MK.raw(ICON_PATHS[name])}</svg>`);
