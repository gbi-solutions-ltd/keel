// ItemCard: one piece of equipment in the catalogue: what it is and whether it is free today.
// props { item, requestHref }: requestHref is set only for a role that may request a loan.
MK.component('ItemCard', ({ item, requestHref }) => MK.html`
  <article class="item-card card">
    <div class="item-card__head">
      <h2 class="item-card__name">${item.name}</h2>
      ${MK.components.ItemAvailabilityBadge({ availability: item.availability })}
    </div>
    <p class="item-card__meta muted"><span class="mono">${item.asset_tag}</span>, ${MK.t(`ItemCard.category.${item.category}`)}</p>
    <p class="item-card__description">${item.description}</p>
    ${requestHref ? MK.html`<a class="button item-card__action" href="${requestHref}" aria-label="${MK.t('ItemCard.requestFor', { name: item.name, tag: item.asset_tag })}">${MK.t('ItemCard.request')}</a>` : ''}
  </article>
`, { layer: 'domain' });
