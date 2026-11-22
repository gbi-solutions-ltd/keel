// RecoveryCodes: codes shown once, to download or copy. Each works once if the user loses their
// other methods. props { codes, filename }
MK.component('RecoveryCodes', ({ codes, filename = 'recovery-codes.txt' }) => MK.html`
  <div class="recovery-codes">
    <ol class="recovery-codes__list mono">${codes.map((c) => MK.html`<li>${c}</li>`)}</ol>
    <p class="muted">Keep these somewhere safe, away from your phone. We will not show them again.</p>
    <a class="button" href="data:text/plain;charset=utf-8,${encodeURIComponent(codes.join('\n') + '\n')}" download="${filename}">Download codes</a>
  </div>
`, { layer: 'composite' });
