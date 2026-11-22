// LoanStatusBadge: a loan's status as a Badge. Maps the domain value to a tone and our label, so
// Badge stays free of the domain. props { status: 'requested'|'approved'|'declined'|'on_loan'|'returned' }
const LOAN_TONES = { requested: 'warning', approved: 'success', declined: 'danger', on_loan: 'info', returned: 'neutral' };
MK.component('LoanStatusBadge', ({ status }) => MK.components.Badge({
  tone: LOAN_TONES[status] ?? 'neutral',
  label: MK.t(`LoanStatusBadge.${status}`),
}), { layer: 'domain' });
