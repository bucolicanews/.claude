---
name: feedback-mobile-forms-pattern
description: Validated UI conventions for mobile layout bugs and cash-payment forms on DeliveryHub
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e5d5a35d-2a3a-4072-8b13-7ab7a3847924
  modified: 2026-09-02T12:43:07.784Z
---

Two conventions confirmed by the user (2026-08-16, session fixing several mobile layout bugs on [[project-deliveryhub]]) — apply them by default to similar screens, not just on request:

**1. Recurring root cause for "elemento fora da tela" / "cortando no mobile" bugs:** almost always a `flex` row (tabs, header buttons, action buttons) missing `flex-wrap`, or a flex child with `flex-shrink-0`/no `min-w-0` sitting inside a parent with `overflow-hidden` — the row/child refuses to shrink and pushes the whole page sideways, or gets silently clipped instead of scrolling. Fixed instances so far: `restaurante-financeiro` (period tabs), `restaurante-combos` (long combo name), `restaurante-produtos` (header buttons), `restaurante-salao` (venda balcão modal height, comanda payment row), `garcom-portal` (payment row). Standard fix: add `flex-wrap` to the row, `min-w-0`/`break-words` to the text that must shrink/wrap, and on primary action buttons `w-full sm:w-auto` so they drop to their own full-width line instead of getting squeezed.

**2. Cash-payment field placement, confirmed liked ("gostei da posição do botão"):** in any partial/final payment form (valor + forma de pagamento + submit button), when `forma === 'cash'`, the "valor recebido do cliente" input must render **above** the submit button (not below/after it as it originally was), with `border-2 border-red-500` and placeholder `"Informe o valor pago pelo cliente"`. The submit button itself always renders last, full-width (`w-full`), after any conditional cash fields. Applied in `restaurante-salao/index.jsx` (both `VendaBalcaoModal` and `ComandaModal`) and `garcom-portal/index.jsx` (`PagamentoParcial`) — same pattern should be reused if a similar payment form shows up elsewhere (e.g. future PDV/caixa screens).

**Why:** user explicitly confirmed liking the button-below-cash-field layout and asked to replicate it across the other two payment forms without re-explaining the spec — treat it as the standing convention for this app, not a one-off request.
**How to apply:** when building or fixing any payment-entry UI in this codebase, default to this layout (fields → conditional cash field with red border → full-width submit button) and check any new flex row for wrap/shrink safety before shipping, especially in modals/panels that are tested on real phones.

See also [[reference_may_memory_vault]]'s `DIRETRIZES-UX-UI.md` (Nielsen heuristic #4 "Consistência e padronização" and the mobile-first accessibility checklist) — this is the concrete instance of that framework for this codebase.

**Recurrence (2026-08-23):** shipped a brand-new list row (checkbox + product name + comanda label + "Ver comanda" button, in the fechar-caixa "Pedidos ainda em preparo" screen) without applying this pattern up front, and the user hit the exact same "muitas letras... ficando espremido" symptom immediately on first use. User's follow-up: "sempre observe a responsividade para a melhor visão no celular" — a standing instruction, not scoped to fixing old screens. **How to apply (reinforced):** apply the flex-wrap/min-w-0/break-words checklist proactively to every NEW row/card you write in this codebase, not just when retrofitting a reported bug — a 3+ item flex row (checkbox/icon + primary label + secondary label + action button) on a card that will render at mobile width should default to a stacked two-line layout (primary label full-width on its own line with `truncate`/`break-words`, secondary label + action button on a second line with `min-w-0`/`flex-shrink-0`) rather than cramming everything into one `flex items-center` row.
