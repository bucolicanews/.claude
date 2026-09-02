---
name: feedback-layout-debugging
description: "When a Tailwind height/scroll layout isn't working, diagnose the className chain for constraint-canceling classes before inventing new calc()/height values"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b1781813-2e2b-49bf-b197-b81bd21590be
  modified: 2026-09-02T12:43:16.107Z
---

Don't iterate blindly on layout height/scroll bugs by guessing new `calc()` formulas or vh percentages. Before touching any height/overflow class, read the **full existing className chain** of the affected element and every ancestor up to the scroll root, specifically hunting for a class that **cancels** an intended constraint — e.g. a later `md:max-h-none` silently overriding an earlier `max-h-[...]`, `overflow-visible` re-added downstream, or a flex/grid item missing `min-h-0` (which locks it to content size and blocks its own `overflow-y-auto` child from ever scrolling, since default `min-height: auto` on flex/grid items refuses to shrink below content).

**Why:** On `/restaurante/delivery` (deliveryhub_white_label), several rounds of "não funcionou" happened while I kept rewriting `calc()` height formulas and restructuring the flex chain. The actual bug was mundane and fully diagnosable from the CSS alone: a `md:max-h-none` on the detail card canceled its own height cap on desktop (so content grew past the viewport and got clipped invisibly by the page's `overflow-hidden` root — no scrollbar ever appears), and the list card was missing `min-h-0`. No live browser inspection was needed to find this — careful reading of the existing classes would have caught it immediately instead of several iterations of restructuring. The user explicitly called this out: "NUNCA INVENTE, SIGA AS REGRAS QUE EU LHE DER" — i.e. don't freelance-redesign a layout when the actual ask is a small, targeted, previously-working fix.

**How to apply:** On any "layout broken / not scrolling / overflowing" report, first grep/read the complete existing class chain top to bottom on that exact element before writing new classes. Look specifically for `*-none`, conflicting `max-h`/`h-`/`overflow-*` at different breakpoints, and missing `min-h-0` on flex/grid items with an internal `overflow-y-auto` child. Only fall back to restructuring the flex/grid chain itself if that audit doesn't turn up a canceling class. Treat "this used to work" from the user as a strong signal the fix is small and local, not architectural.

See also [[reference_may_memory_vault]]'s `DIRETRIZES-UX-UI.md` — this is a "don't invent" instance of Nielsen heuristic #4 (consistência/padronização) and the Lean UX outcomes-over-outputs principle: fix the reported break, don't freelance-redesign.
