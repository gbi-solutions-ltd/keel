// FormSkeleton: the loading state of a page with a summary above a form, shaped like it: a title
// and lines for the summary, then a label and a field per form field. props { fields }
MK.component('FormSkeleton', ({ fields = 3 }) => MK.html`
  <div class="form-skeleton" role="status">
    <span class="visually-hidden">${MK.t('FormSkeleton.loading')}</span>
    <div class="form-skeleton__body" aria-hidden="true">
      <div class="card form-skeleton__summary">
        ${MK.components.SkeletonBox({ shape: 'title' })}
        ${MK.components.SkeletonBox({ shape: 'text' })}
        ${MK.components.SkeletonBox({ shape: 'text' })}
      </div>
      <div class="card form-skeleton__fields">
        ${Array.from({ length: fields }, () => MK.html`<div class="form-skeleton__field">
          ${MK.components.SkeletonBox({ shape: 'text' })}
          ${MK.components.SkeletonBox({ shape: 'field' })}
        </div>`)}
      </div>
    </div>
  </div>
`, { layer: 'composite' });
