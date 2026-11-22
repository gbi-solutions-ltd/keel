// TourList: the page tours a user can take, each a link that starts it on its page.
// props { tours: { id, title, description, href }[] }
MK.component('TourList', ({ tours }) => MK.html`
  <ul class="tour-list">
    ${tours.map((t) => MK.html`
      <li class="tour-list__item">
        <div>
          <h3 class="tour-list__title">${t.title}</h3>
          <p class="tour-list__description muted">${t.description}</p>
        </div>
        <a class="button" href="${t.href}" aria-label="Take the tour: ${t.title}">Take the tour</a>
      </li>`)}
  </ul>
`, { layer: 'composite' });
