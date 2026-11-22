// ExportMenu: request an export and fetch it when ready. Exports are built by the API, in the
// background, for the whole filtered result; the browser only asks and downloads.
// props { open, menuAction, exportAction, tour?, job: null | { format, status: 'preparing'|'ready', href, filename } }
const EXPORT_FORMATS = [{ value: 'csv', label: 'CSV' }, { value: 'xlsx', label: 'Excel' }, { value: 'pdf', label: 'PDF' }];
MK.component('ExportMenu', ({ open, menuAction, exportAction, job, tour }) => MK.html`
  <div class="export-menu popover-menu" ${tour ? MK.raw(`data-tour="${tour}"`) : ''}>
    <button type="button" class="button" aria-expanded="${String(open)}" aria-controls="export-menu" data-action="${menuAction}">Export</button>
    ${open ? MK.html`
    <div class="popover-menu__panel" id="export-menu" role="group" aria-label="Export format">
      ${EXPORT_FORMATS.map((f) => MK.html`<button type="button" class="button button--block" data-action="${exportAction}" data-value="${f.value}">${f.label}</button>`)}
    </div>` : ''}
    <p class="export-menu__status" role="status">${job
      ? job.status === 'ready'
        ? MK.html`Your ${job.format.toUpperCase()} export is ready. <a href="${job.href}" download="${job.filename}">Download ${job.filename}</a>`
        : MK.html`Preparing your ${job.format.toUpperCase()} export.`
      : ''}</p>
  </div>
`, { layer: 'composite' });
