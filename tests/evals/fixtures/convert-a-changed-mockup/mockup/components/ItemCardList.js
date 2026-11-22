// ItemCardList: the catalogue's items as a grid of cards, one column on a phone.
// props { items, label, requestHref(item) | null }
MK.component('ItemCardList', ({ items, label, requestHref }) => MK.html`
  <ul class="item-card-list" aria-label="${label}">
    ${items.map((item) => MK.html`<li class="item-card-list__item">${MK.components.ItemCard({ item, requestHref: requestHref ? requestHref(item) : null })}</li>`)}
  </ul>
`, { layer: 'domain' });
