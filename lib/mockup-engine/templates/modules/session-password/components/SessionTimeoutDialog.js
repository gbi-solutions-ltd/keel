// SessionTimeoutDialog: the warning before an idle session is signed out. Escape means stay.
// props { minutes, stayAction, signOutAction }
MK.component('SessionTimeoutDialog', ({ minutes, stayAction, signOutAction }) => MK.components.Dialog({
  id: 'session-timeout',
  title: 'Are you still there?',
  cancelAction: stayAction,
  body: MK.html`<p>For your security, you will be signed out in ${minutes === 1 ? '1 minute' : `${minutes} minutes`} unless you choose to stay.</p>`,
  actions: MK.html`
    <button type="button" class="button" data-action="${signOutAction}">Sign out</button>
    <button type="button" class="button button--primary" data-action="${stayAction}">Stay signed in</button>`,
}), { layer: 'composite' });
