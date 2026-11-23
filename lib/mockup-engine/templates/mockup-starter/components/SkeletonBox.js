// SkeletonBox: one placeholder shape. props { shape: 'text' | 'title' | 'badge' | 'value' | 'chart' }
// Shape-matched skeletons are built from these, so a page's loading state has its real layout.
MK.component('SkeletonBox', ({ shape = 'text' }) => MK.html`
  <span class="skeleton-box skeleton-box--${shape}"></span>
`, { layer: 'primitive' });
