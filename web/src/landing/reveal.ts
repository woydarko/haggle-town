let io: IntersectionObserver | null = null;

/** Ref callback: sets data-in the first time the element scrolls into view. Without IntersectionObserver it shows at once.
 *  An attribute, not a class: React rewrites className on re-render (e.g. a merchant card toggling "talking") and would drop it. */
export function reveal(el: HTMLElement | null) {
  if (!el) return;
  if (!("IntersectionObserver" in window)) {
    el.dataset.in = "";
    return;
  }
  io ??= new IntersectionObserver(
    (entries) => {
      for (const e of entries) {
        if (!e.isIntersecting) continue;
        (e.target as HTMLElement).dataset.in = "";
        io?.unobserve(e.target);
      }
    },
    { threshold: 0.15 },
  );
  io.observe(el);
}
