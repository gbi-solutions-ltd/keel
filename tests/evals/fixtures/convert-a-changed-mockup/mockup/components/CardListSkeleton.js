// CardListSkeleton: the loading state of a list of cards, shaped like it (a title, a badge, lines
// of detail). props { count, layout: 'grid' (the catalogue: up to three across) | 'list' (one
// card a row, as loans are) }
MK.component('CardListSkeleton', ({ count = 6, layout = 'grid' }) => MK.html`
  <div class="card-list-skeleton" role="status">
    <span class="visually-hidden">${MK.t('CardListSkeleton.loading')}</span>
    <ul class="card-list-skeleton__list card-list-skeleton__list--${layout}" aria-hidden="true">
      ${Array.from({ length: count }, () => MK.html`<li class="card-list-skeleton__card card">
        ${MK.components.SkeletonBox({ shape: 'title' })}
        ${MK.components.SkeletonBox({ shape: 'badge' })}
        ${MK.components.SkeletonBox({ shape: 'text' })}
        ${MK.components.SkeletonBox({ shape: 'text' })}
      </li>`)}
    </ul>
  </div>
`, { layer: 'composite' });
