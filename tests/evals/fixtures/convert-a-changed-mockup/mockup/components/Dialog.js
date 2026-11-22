// Dialog: a modal dialog with a title, a body and actions. A native <dialog> opened modally; its
// Escape fires the cancel action. props { id, title, body, actions, cancelAction }
MK.component('Dialog', ({ id, title, body, actions, cancelAction }) => MK.html`
  <dialog class="dialog" data-modal aria-labelledby="${id}-title" data-action="${cancelAction}" data-on="cancel">
    <h2 class="dialog__title" id="${id}-title">${title}</h2>
    <div class="dialog__body">${body}</div>
    <div class="dialog__actions">${actions}</div>
  </dialog>
`, { layer: 'composite' });
