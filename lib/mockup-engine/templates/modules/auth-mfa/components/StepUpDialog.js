// StepUpDialog: confirm it is really the user before a sensitive change. The server asks for this
// (step_up_required) and the change is retried once the user passes.
// props { purpose, methods: { value, label }[], method, sent, destination, error }
MK.component('StepUpDialog', ({ purpose, methods, method, sent, destination, error }) => MK.components.Dialog({
  id: 'step-up',
  title: 'Confirm it is you',
  cancelAction: 'closeDialog',
  body: MK.html`
    <p>To ${purpose}, enter a code from one of your methods.</p>
    ${MK.components.RadioGroup({ name: 'step-up-method', legend: 'Method', value: method, options: methods, action: 'setStepUpMethod' })}
    ${method === 'email' ? (sent
      ? MK.components.Notice({ tone: 'info', text: `We sent a code to ${destination}.` })
      : MK.html`<button type="button" class="button" data-action="sendStepUpCode">Send code</button>`) : ''}
    ${MK.components.OneTimeCodeField({ id: 'step-up-code', label: 'Code', error, action: 'setStepUpCode' })}`,
  actions: MK.html`
    <button type="button" class="button" data-action="closeDialog">Cancel</button>
    <button type="button" class="button button--primary" data-action="confirmStepUp">Confirm</button>`,
}), { layer: 'domain' });
