// en-GB: the default locale (the first strings file loaded). Every user-visible string in the
// starter comes from here through MK.t (skills/mockup/references/mockup-conventions.md, Strings and locales).
// Keys: <page-id>.<thing>, <ComponentName>.<thing>, shell.<thing>, common.<thing> for shared words.
MK.strings('en-GB', {
  // AppLayout shell
  'shell.nav.access': 'Access',
  'shell.nav.invoices': 'Invoices',
  'shell.nav.label': 'Main',

  // pages/access.html
  'access.error': 'We could not load the roles. Please refresh.',
  'access.grid.caption': 'Permissions held by each role',
  'access.intro': 'Each role and the permissions it holds. Use the arrow keys to move through the table.',
  'access.loading.permission': 'Permission',
  'access.loading.role': 'Role',
  'access.title': 'Who can do what',

  // pages/invoices.html
  'invoices.apply': 'Apply',
  'invoices.column.amount': 'Amount',
  'invoices.column.customer': 'Customer',
  'invoices.column.issued': 'Issued',
  'invoices.column.number': 'Number',
  'invoices.column.status': 'Status',
  'invoices.empty.body': 'Invoices you issue will appear here.',
  'invoices.empty.title': 'No invoices yet',
  'invoices.error': 'We could not load invoices. Please refresh.',
  'invoices.filters.label': 'Filter invoices',
  'invoices.minimum.hint': 'Invoices of at least this amount',
  'invoices.minimum.label': 'Minimum amount',
  'invoices.noMatch.body': 'Try another search, status or a lower amount.',
  'invoices.noMatch.title': 'No invoices match',
  'invoices.status.all': 'All statuses',
  'invoices.status.hint': 'Invoices in this status',
  'invoices.status.label': 'Status',
  'invoices.search.hint': 'Number or customer name',
  'invoices.search.label': 'Search',
  'invoices.table.caption': 'Invoices',
  'invoices.title': 'Invoices',

  // components
  'ErrorPage.reference': 'Reference',
  'ErrorPage.reload': 'Reload page',
  'ErrorState.body': 'Please try again.',
  'ErrorState.title': 'Something went wrong',
  'ForbiddenPage.body': 'Ask an administrator if you need it.',
  'ForbiddenPage.title': 'You do not have access to this page',
  'InvoiceStatusBadge.open': 'Open',
  'InvoiceStatusBadge.overdue': 'Overdue',
  'InvoiceStatusBadge.paid': 'Paid',
  'MoneyField.currency': '({currency})',
  'Pagination.label': 'Pagination',
  'Pagination.next': 'Next page',
  'Pagination.page': 'Page {page}',
  'Pagination.previous': 'Previous page',
  'PermissionGrid.held': 'Yes',
  'PermissionGrid.notHeld': 'No',
  'PermissionGrid.permission': 'Permission',
  'TableSkeleton.loading': 'Loading',
});
