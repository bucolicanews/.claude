---
name: deliveryhub-caixa-fiado-multi-caixa
description: Fechamento de caixa com pendências (fiado, JÁ EM MAIN) + múltiplos caixas simultâneos Principal/Bar/Salão (ainda só na branch feature/caixa-fiado-multi-caixa) no deliveryhub_white_label
metadata: 
  node_type: memory
  type: project
  originSessionId: af673b9c-a5ef-4e24-9420-a36aeebebff7
  modified: 2026-07-23T15:19:15.946Z
---

**Status verificado em 2026-07-23:** as duas features foram commitadas juntas na branch `feature/caixa-fiado-multi-caixa`, mas só a feature 1 (fiado) foi mergeada em `main` nos dois repos (`1836a4b` no frontend, `cc94b7e` no backend). A feature 2 (multi-caixa nome/is_principal, commit `6b53522` no backend) **segue só na branch remota**, não mergeada — branch inteira ainda existe (`origin/feature/caixa-fiado-multi-caixa` nos dois repos), não deletar.

**Continuação encontrada (frontend only, não mergeada):** branch local `feature/colaboradores-caixa` (2 commits acima de main: `9b1c9f7` "feat: suporta múltiplos caixas simultâneos" + `41439ab` "feat: colaboradores com login por setor + editar/reabrir caixa") parece ser um retrabalho/continuação do multi-caixa, acrescentando colaboradores com login por setor — não documentado em memória antes, não confirmado com o usuário o que é/se está ativo. Existe também branch local `fix/comanda-data-pagamento-e-filtros` (mesma base + 1 commit "fix: comanda paga em dia diferente da abertura + filtro de comandas") — mensagem idêntica a um commit já mergeado em main (`98644a6`), provável branch abandonada/duplicada, confirmar com o usuário antes de deletar ou retomar.

Descrição original (branch `feature/caixa-fiado-multi-caixa`, repo principal + submodule `server_delivery`, ambos criados a partir da main): duas features de caixa pedidas pelo usuário.

**1. Fechar caixa com pendências (fiado):** `fecharCaixa` aceita `permitir_pendencias: true` no body pra pular o bloqueio de pedidos/comandas/mesas abertos. Grava `fechado_com_pendencias` + snapshot em `pendencias_fechamento`. Pagamento de algo que ficou pendente num caixa já fechado realoca automaticamente pro caixa aberto no momento do pagamento (`salao-pdv.service.ts` função `pagar()`).

**2. Múltiplos caixas simultâneos:** `caixas` ganhou `nome` (Bar/Salão/Principal) e `is_principal` (só 1 principal aberto por vez, índice único parcial). Decisão de design: **estratégia aditiva, não big-bang** — `getCaixa()` (usado pelo dashboard) continua devolvendo só o caixa **principal**, formato inalterado, zero regressão pra quem não usa a feature nova. Caixas secundários são geridos por endpoint/painel novos (`getCaixasAbertos`, `OutrosCaixasPanel.jsx`). Operador escolhe o caixa ao abrir turno (garçom-portal e restaurante-salão mostram seletor quando há >1 caixa aberto, salvo em `localStorage` via `src/utils/caixaSessao.js`). Delivery/motoboy sempre usa o caixa principal (não há operador escolhendo nesses fluxos).

**Why:** Cliente que some pode fechar o caixa diário sem travar em comanda de hóspede/fiado; e o restaurante quer caixa separado por ponto de venda (bar/salão) rodando ao mesmo tempo.

**How to apply:** Se for expandir isso — cada lugar que faz `.from('caixas').eq('status','aberto')` no `server_delivery` precisa decidir entre `is_principal` (fallback automático) ou `caixa_id` explícito vindo do operador; nunca usar `.maybeSingle()` sem um desses dois filtros, porque agora pode haver mais de 1 caixa aberto por restaurante e a query quebra.

**Falta (não implementado ainda, ficou de fora do escopo por tempo):** testar fluxo end-to-end no navegador (usuário roda os servers manualmente, ver [[feedback_usuario_roda_servers]]); UI de fechamento por `FecharCaixaModal` completa só existe pro caixa Principal — caixas secundários fecham via `OutrosCaixasPanel` com um fluxo mais simples (confirm nativo do browser em vez do modal de conferência completo); não há testes automatizados cobrindo isso.
