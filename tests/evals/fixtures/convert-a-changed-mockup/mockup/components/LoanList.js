// LoanList: loans as a list of cards, one per loan, readable on a phone without scrolling sideways.
// A coordinator's list shows who asked and the actions the server allows on each loan
// (allowed_actions, already filtered by role in the page's load); a staff member's own list shows
// neither. A declined loan shows the coordinator's reason to both (decision D-1). props { label, loans, showRequester, actionNames: { approve, decline, hand_out, return }
// | null }: each action name is the page action a button fires, with the loan's id as data-id.
const LOAN_ACTION_TONES = { approve: 'button--primary', decline: '', hand_out: 'button--primary', return: 'button--primary' };
MK.component('LoanList', ({ label, loans, showRequester = false, actionNames = null }) => MK.html`
  <ul class="loan-list" aria-label="${label}">
    ${loans.map((l) => MK.html`
      <li class="loan-list__item card">
        <div class="loan-list__head">
          <h2 class="loan-list__title" id="loan-${l.id}-title">${l.item.name}</h2>
          ${MK.components.LoanStatusBadge({ status: l.status })}
        </div>
        <dl class="loan-list__details">
          <div class="loan-list__detail"><dt>${MK.t('LoanList.reference')}</dt><dd class="mono">${l.reference}</dd></div>
          <div class="loan-list__detail"><dt>${MK.t('LoanList.assetTag')}</dt><dd class="mono">${l.item.asset_tag}</dd></div>
          ${showRequester ? MK.html`<div class="loan-list__detail"><dt>${MK.t('LoanList.requester')}</dt><dd>${l.requester.name}</dd></div>` : ''}
          <div class="loan-list__detail"><dt>${MK.t('LoanList.dates')}</dt><dd>${MK.t('common.dateRange', { from: MK.format.date(l.from), to: MK.format.date(l.to) })}</dd></div>
          <div class="loan-list__detail"><dt>${MK.t('LoanList.requested')}</dt><dd>${MK.format.dateTime(l.requested_at)}</dd></div>
          <div class="loan-list__detail loan-list__detail--wide"><dt>${MK.t('LoanList.purpose')}</dt><dd>${l.purpose}</dd></div>
          ${l.status === 'declined' && l.decline_reason ? MK.html`<div class="loan-list__detail loan-list__detail--wide"><dt>${MK.t('LoanList.declineReason')}</dt><dd>${l.decline_reason}</dd></div>` : ''}
        </dl>
        ${actionNames && l.allowed_actions.length ? MK.html`<div class="loan-list__actions">
          ${l.allowed_actions.map((a) => MK.html`<button type="button" id="loan-${a}-${l.id}" class="button ${LOAN_ACTION_TONES[a]}" data-action="${actionNames[a]}" data-id="${l.id}" aria-label="${MK.t(`LoanList.action.${a}.label`, { reference: l.reference })}">${MK.t(`LoanList.action.${a}`)}</button>`)}
        </div>` : ''}
      </li>`)}
  </ul>
`, { layer: 'domain' });
