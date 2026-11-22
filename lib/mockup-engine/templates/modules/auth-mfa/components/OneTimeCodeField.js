// OneTimeCodeField: a code from an authenticator app, email or text, or a recovery code.
// Numeric keypad and the platform's code autofill for one-time codes; plain text for recovery
// codes. props { id, label, recovery, error, action }
MK.component('OneTimeCodeField', ({ id, label, recovery = false, error, action }) => MK.components.TextField({
  id,
  label,
  type: 'text',
  autocomplete: recovery ? 'off' : 'one-time-code',
  inputmode: recovery ? null : 'numeric',
  hint: recovery ? 'Each recovery code works once.' : 'Six digits.',
  error,
  action,
}), { layer: 'composite' });
