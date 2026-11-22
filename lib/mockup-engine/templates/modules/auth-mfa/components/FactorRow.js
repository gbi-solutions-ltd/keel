// FactorRow: one sign-in method on the security page, its state, and what the user can do.
// A control that cannot be used says why, rather than disappearing.
// props { title, detail, on, actionLabel, action, value, disabledReason }
MK.component('FactorRow', ({ title, detail, on, actionLabel, action, value, disabledReason }) => MK.html`
  <div class="factor-row">
    <div class="factor-row__text">
      <p class="factor-row__title">${title} ${MK.components.Badge({ tone: on ? 'success' : 'neutral', label: on ? 'On' : 'Off' })}</p>
      <p class="muted">${detail}</p>
      ${disabledReason ? MK.html`<p class="factor-row__reason" id="reason-${value}">${disabledReason}</p>` : ''}
    </div>
    <button type="button" class="button" data-action="${action}" data-value="${value}"
      ${disabledReason ? MK.raw(`disabled aria-describedby="reason-${value}"`) : ''}>${actionLabel}</button>
  </div>
`, { layer: 'domain' });
