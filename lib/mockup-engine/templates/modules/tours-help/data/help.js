// Help content (the tours module): the page tours and the support contact. Product copy, not API
// data, so it lives beside the fixtures rather than in them; becomes the app's src/help/content.ts.
//
// A tour: { id, version, route, title, description, permission, steps: [{ target, title, body }] }
//   - route:      the page it runs on; it starts there, never elsewhere
//   - permission: who is offered it (the page's own permission, usually)
//   - version:    raise it when the page changes enough that people should see the tour again
//   - target:     a data-tour="..." anchor on the page; a step whose anchor is missing (hidden by
//                 a permission, say) is skipped, so one tour serves every role
// Copy is plain text: driver.js renders it as HTML, so it must never come from user data.
window.HELP = {
  contact: {
    email: 'support@service.example',
    hours: 'Monday to Friday, 08:00 to 17:00',
  },
  tours: [
    {
      id: 'dashboard',
      version: 1,
      route: '/dashboard',
      title: 'Dashboard',
      description: 'The figures on the dashboard and how to change the period.',
      permission: 'dashboard:read',
      steps: [
        { target: 'period', title: 'Choose a period', body: 'Every figure on this page covers the period you choose here.' },
        { target: 'stats', title: 'Headline figures', body: 'Each figure is compared with the period before it.' },
        { target: 'chart', title: 'Daily volume', body: 'Show the chart as a table to read exact amounts.' },
        { target: 'search', title: 'Find anything', body: 'Press Ctrl K, or /, on any page to search pages and records.' },
      ],
    },
    {
      id: 'invoices',
      version: 1,
      route: '/invoices',
      title: 'Invoices',
      description: 'Filtering, choosing columns and exporting the invoice report.',
      permission: 'invoice:read',
      steps: [
        { target: 'filters', title: 'Filter the report', body: 'Narrow the list by status and channel. Columns chooses what the table shows.' },
        { target: 'export', title: 'Export', body: 'Export the filtered list as CSV, Excel or PDF. Large exports are prepared in the background.' },
        { target: 'table', title: 'Open a invoice', body: 'Select a reference to see the details of that invoice.' },
      ],
    },
  ],
};
