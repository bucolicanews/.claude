---
name: deliveryhub-gorjeta-estimada-qr-cliente
description: "link do cliente (QR da comanda) mostra gorjeta estimada antes da comanda ser paga — MERGEADO+PUSHADO, TESTADO"
metadata: 
  node_type: memory
  type: project
  originSessionId: 9e881dd1-4b9e-4669-9856-ee5151393956
  modified: 2026-07-27T19:32:51.433Z
---

Bug reportado em 2026-07-27: cliente lendo QR da comanda (`/mesa-acompanhar/:token`, `src/pages/mesa-acompanhar/index.jsx`) via `mesa-acompanhar.controller.ts` → `SalaoService.acompanharPorToken` não via gorjeta aparecer nem somar no Total/Falta pagar.

**Causa raiz:** `orders.gorjeta_valor` só é gravado quando a comanda é efetivamente paga (`SalaoPdvService.pagar()`, garçom/caixa escolhe o valor na hora) — enquanto a comanda está aberta o campo é `null`, então mostrava R$0,00 mesmo o restaurante tendo `gorjeta_percentual` configurado.

**Fix:** em `salao.service.ts` (`acompanharPorToken`), se `gorjeta_valor` ainda for `null` e a comanda não estiver `'paga'`, calcula estimativa = `(subtotal - desconto + acréscimo) * percentual/100` e já soma no Total/Falta pagar, retornando `gorjeta_estimativa: true`. Frontend mostra "· estimativa" do lado do label. Quando a comanda é paga, volta a mostrar o valor real cobrado (sem recalcular).

**Why:** cliente acompanhando a conta pelo QR quer ver o valor real que vai pagar (incluindo gorjeta sugerida), não só produtos.

**Cuidado:** não mexi em `saldoDevedor()` (usado pelo pagamento real em `SalaoPdvService.pagar`) — a estimativa é calculada só localmente dentro de `acompanharPorToken`, pra não arriscar inflar valores cobrados de verdade.

**Status:** testado, mergeado em main (frontend+backend submodule+standalone VPS sincronizados) em 2026-07-27. Sem migration (só lógica de código).
