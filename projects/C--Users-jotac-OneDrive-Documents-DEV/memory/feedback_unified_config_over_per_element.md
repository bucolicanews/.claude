---
name: feedback-unified-config-over-per-element
description: User prefers one shared style config over per-element/per-button config panels in admin settings UIs
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 50b2d613-ecde-4a59-86fe-fa692430fb34
  modified: 2026-09-02T20:59:33.964Z
---

When building admin-configurable styling for a group of similar UI elements (e.g. header action buttons: Admin, Carrinho, Pedidos, Sair, Seja um entregador/vendedor), default to **one shared config group** applied to all of them, not a separate config panel per element — even after initially building per-element config on request, the user asked to collapse it back into one ("unifique as configurações desses botões não precisa ter duas").

**Why:** keeps the admin panel from ballooning (a per-element approach for N buttons × ~6 fields each gets unwieldy fast) and matches how the user actually wants to operate the panel — tweak one thing, it applies everywhere it's relevant. This surfaced in [[project_deliveryhub]] while building header-button styling for the PediuVai rebrand.

**How to apply:** when a task says "add editable X (background/border/color/etc.) for element A, then do the same for elements B, C, D...", propose (or default to) a single shared style block covering all of them first — via `AskUserQuestion` if genuinely ambiguous whether shared vs. per-element control is wanted — rather than mechanically duplicating the same 5-6 field group per element. Reserve per-element config for elements that are semantically distinct enough to need their own values (e.g. the "Admin" button kept a unique `botao_admin_texto` field for its label, since other buttons don't have editable text).
