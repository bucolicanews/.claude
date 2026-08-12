---
name: deliveryhub-fix-taxa-cartao-total
description: "Fix taxa de cartão não somava no Total da comanda nem na impressão de conferência (Salão) — MERGEADO EM MAIN"
metadata: 
  node_type: memory
  type: project
  originSessionId: c719a40e-9a6f-440c-9820-298c7c8feb97
  modified: 2026-07-23T21:15:44.908Z
---

Bug relatado pelo usuário na comanda #6 (Salão): "Taxa cartão" de pagamento parcial no cartão (registrado pelo garçom antes do caixa fechar) não entrava no "Total (comanda + gorjeta)" nem na impressão de conferência — só "Falta pagar" batia (vinha do saldo do backend, que já somava certo).

Causa: em `src/pages/restaurante-salao/index.jsx`, `taxaCartaoValorFinal` só calculava a taxa da forma de pagamento **selecionada agora** pro fechamento, ignorando `taxa_cartao_valor` já registrado em `comanda.pagamentos` de pagamentos parciais anteriores.

Fix: somado `taxaCartaoRegistrada` (soma de `p.taxa_cartao_valor` dos pagamentos já feitos) em `taxaCartaoTotalExibida`, usado no Total exibido, no rótulo "+ taxa", no "Falta pagar" e no `valores.taxaCartao` mandado pra impressão (`imprimirConferencia`).

Commits na branch `fix/taxa-cartao-total-comanda`, mergeados em `main` e pushados em 2026-07-23 (merge commit `b43f540`):
- `25440b0` fix: taxa de cartão de pagamento parcial não somava no total
- `55a086f` chore: ajusta config local (Supabase local, proxy backend local `localhost:3002`) e logo/favicon — mudanças do próprio usuário, não relacionadas ao bug, commitadas junto a pedido dele.

**Why:** usuário testou manualmente na tela (não via automação, extensão claude-in-chrome estava desconectada), confirmou "suba para deploy" e depois pediu merge explícito em main.

**How to apply:** fix já está em `main`/`origin main` (`b43f540`). Backend (`server_delivery`, submodule e standalone) checado e já sincronizado no mesmo commit `076b436` — sem pendência de backend pra essa tarefa (fix foi só frontend). Junto no mesmo push já estavam mergeados `de20050` (fix voz da cozinha parava após tela ligada horas) e a troca de `favicon.ico`/`public/favicon.ico` (logo/ico) — confirmado 2026-07-23 que ambos estão em `main`. Deploy real em si (EasyPanel) fica fora do meu alcance, ver [[feedback_trigger_suba_para_deploy]] pro fluxo padrão.
