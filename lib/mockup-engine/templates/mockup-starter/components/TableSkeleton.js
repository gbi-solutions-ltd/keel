// TableSkeleton: a table's loading state with its real header. props { columns: string[], rows }
// data-clip: a narrow screen cuts the placeholder columns off by design (spill-check allows it)
MK.component('TableSkeleton', ({ columns, rows = 6 }) => MK.html`
  <div class="table-skeleton" role="status" data-clip>
    <span class="visually-hidden">${MK.t('TableSkeleton.loading')}</span>
    <table class="table-skeleton__table" aria-hidden="true">
      <thead><tr>${columns.map((c) => MK.html`<th>${c}</th>`)}</tr></thead>
      <tbody>
        ${Array.from({ length: rows }, () => MK.html`<tr>${columns.map(() => MK.html`<td>${MK.components.SkeletonBox({ shape: 'text' })}</td>`)}</tr>`)}
      </tbody>
    </table>
  </div>
`, { layer: 'composite' });
