let io: IntersectionObserver | null = null;

/** Ref callback for section headings: marks the element data-r (hidden by CSS until seen), then data-in once it scrolls into view.
 *  Attributes, not classes: React rewrites className on re-render and would drop a class it did not set. */
export function reveal(el: HTMLElement | null) {
  if (!el || "in" in el.dataset) return;
  if (!("IntersectionObserver" in window)) {
    el.dataset.in = "";
    return;
  }
  el.dataset.r = "";
  io ??= new IntersectionObserver(
    (entries) => {
      for (const e of entries) {
        if (!e.isIntersecting) continue;
        (e.target as HTMLElement).dataset.in = "";
        io?.unobserve(e.target);
      }
    },
    { threshold: 0.2 },
  );
  io.observe(el);
}
