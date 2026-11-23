// RoleCard: one role, what it may do, and how many people hold it.
// props { id, label, description, permissions: { id, label }[], userCount }
MK.component('RoleCard', ({ id, label, description, permissions, userCount }) => MK.html`
  <section class="card role-card" aria-labelledby="role-${id}">
    <div class="row row--between">
      <h2 id="role-${id}">${label}</h2>
      <span class="muted">${userCount === 1 ? '1 user' : `${userCount} users`}</span>
    </div>
    <p class="role-card__description">${description}</p>
    <ul class="role-card__permissions">
      ${permissions.map((p) => MK.html`<li>${p.label}</li>`)}
    </ul>
  </section>
`, { layer: 'domain' });
