// ItemAvailabilityBadge: whether an item is free today, as the server says, as a Badge.
// props { availability: { status: 'free'|'on_loan', due_back_on: 'YYYY-MM-DD'|null } }
MK.component('ItemAvailabilityBadge', ({ availability }) => MK.components.Badge(availability.status === 'free'
  ? { tone: 'success', label: MK.t('ItemAvailabilityBadge.free') }
  : { tone: 'warning', label: MK.t('ItemAvailabilityBadge.onLoan', { date: MK.format.date(availability.due_back_on) }) }
), { layer: 'domain' });
