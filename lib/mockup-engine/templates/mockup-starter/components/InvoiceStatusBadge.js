// InvoiceStatusBadge: maps the domain status to a Badge, so Badge never learns the domain.
// props { status: 'paid' | 'open' | 'overdue' }
// The tone is the mapping; the label is copy, looked up when the badge renders.
const INVOICE_STATUS_TONE = { paid: 'success', open: 'neutral', overdue: 'danger' };
MK.component('InvoiceStatusBadge', ({ status }) => MK.components.Badge({ tone: INVOICE_STATUS_TONE[status], label: MK.t(`InvoiceStatusBadge.${status}`) }), { layer: 'domain' });
