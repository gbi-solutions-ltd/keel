// Stepper: where the user is in a short sequence. props { step, total, label }
MK.component('Stepper', ({ step, total, label }) => MK.html`
  <p class="stepper"><span class="stepper__count">Step ${step} of ${total}</span> ${label}</p>
`, { layer: 'composite' });
