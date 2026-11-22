// DetailList: props { items: { label, value }[] }, value may be MK.html markup
MK.component('DetailList', ({ items }) => MK.html`
  <dl class="detail-list">
    ${items.map((i) => MK.html`<dt>${i.label}</dt><dd>${i.value}</dd>`)}
  </dl>
`, { layer: 'composite' });
