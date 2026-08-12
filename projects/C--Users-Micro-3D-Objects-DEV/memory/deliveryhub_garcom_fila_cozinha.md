---
name: deliveryhub-garcom-fila-cozinha
description: Aba Cozinha no portal do garçom (fila de preparo + tempo médio) — implementada, branch não mergeada
metadata:
  node_type: memory
  type: project
  originSessionId: session-2026-07-24-fila-cozinha
  modified: 2026-07-25T01:07:19.675Z
---

Pedido do usuário em 2026-07-24: nova aba "Cozinha" no portal do garçom (`/garcom/:loginKey`) mostrando fila de itens em preparo/aguardando (restaurante inteiro, não só comandas do garçom logado) com posição na fila, timer ao vivo por item, e tempo médio de preparo dos itens finalizados hoje — pra o garçom responder cliente presencial sobre status/tempo do pedido sem ir até a cozinha.

Decisões confirmadas: granularidade por item (`order_items`, não agrupado por comanda), escopo restaurante inteiro, tempo médio = média de `pronto_em - preparando_em` dos itens prontos hoje.

**Implementado (não testado end-to-end, não mergeado):**
- Backend (submodule `deliveryhub_white_label/server_delivery`, branch `feat/garcom-fila-cozinha`, commit `f131f23`): `SalaoService.filaCozinha()` em `src/salao/salao.service.ts`, endpoint `GET /api/garcom/fila-cozinha` em `src/salao/salao.controller.ts` (dentro do `SalaoController`, herda `GarcomGuard`).
- Frontend (`deliveryhub_white_label`, branch `feat/garcom-fila-cozinha`, commit `c622adf`): `getFilaCozinha()` em `src/services/garcomService.js`; componente `FilaCozinha` + nova aba em `src/pages/garcom-portal/index.jsx` (reusa `useNowTick` de `src/hooks/useNowTick.js` e `formatDuracao` de `src/utils/formatDuracao.js`, já existentes).
- Validado só com `tsc --noEmit` (backend) e `vite build` (frontend), ambos limpos — sem teste funcional real (usuário roda os servers manualmente, ver [[feedback_usuario_roda_servers]]).

**Extensão 2026-07-24 (mesmo dia, mesma branch):** tempo médio quebrado em 3 (`tempoMedioEsperaSegundos` enviado→preparando, `tempoMedioPreparoSegundos` preparando→pronto, `tempoMedioGeralSegundos` enviado→pronto — nomenclatura igual à já usada nos cards de item da tela cozinha). Guard extra: exige `enviado_em` também de hoje (não só `pronto_em`) pra item preso de dias atrás não virar outlier. Mesma info (posição na fila + as 3 médias) levada pro **acompanhamento público via QR** (`/mesa/acompanhar/:token`, `mesa-acompanhar/index.jsx`, backend `acompanharPorToken` em `salao.service.ts` reaproveitando `filaCozinha()`) — cliente vê sem precisar perguntar ao garçom. Componente `TempoMedioTile` extraído pra `src/components/TempoMedioTile.jsx`, compartilhado entre `garcom-portal` e `mesa-acompanhar`.

**Extensão 2 (mesmo dia):** tela pública do QR (`/mesa/acompanhar/:token`) ganhou conferência visual completa da conta — preço unitário/subtotal por item, card com subtotal/desconto/acréscimo/gorjeta/taxa de cartão/total/saldo (reusa `saldoDevedor()`, mesmo cálculo do caixa), e lista de pagamentos parciais já feitos com taxa de cartão discriminada por pagamento. `numero_comanda` também exibido no topo.

**Gotcha confirmado nesta sessão:** processo do backend NestJS rodando `npm run start` (não watch/dev) não recarrega sozinho ao editar `.ts` — usuário viu média com fórmula antiga (commit anterior) até reiniciar manualmente. Reforça [[feedback_backend_restart_apos_pull]] — vale pra qualquer edição de arquivo, não só `git pull`.

**Validado pelo usuário em 2026-07-24** ("está perfeito") após testar local com dados reais — feature completa (fila garçom + tempo médio 3-vias + QR cliente com conta detalhada) confirmada funcionando.

**Extensão 3 (mesmo dia):** fechamento de caixa (`FecharCaixaModal.jsx`) mostra taxa de cartão separada por forma (débito/crédito), não mais um bucket único somado. Backend `calcularResumo` (`restaurante.service.ts`) ganhou campo novo `taxa_por_forma` (mantendo `por_pagamento.taxa_cartao` combinado intacto pra não quebrar outras telas — RelatorioPanel, Financeiro, restaurante-financeiro — que ainda consomem o formato antigo). Branch `fix/taxa-cartao-por-forma-fechamento`, mergeada+pushada+deployada e **validada em produção** em 2026-07-24 (usuário confirmou "está tudo certo" após checar bundle JS em prod continha `taxa_por_forma`).

**Mergeado e pushado em 2026-07-24:** branch `feat/garcom-fila-cozinha` mergeada em `main` nos dois repos (submodule `server_delivery` commit `a02e8a0`, frontend `72eb316` já com ponteiro do submodule atualizado). Push feito pro GitHub nos dois, e clone standalone (`DEV/server_delivery`) sincronizado via `git pull` — mesmo commit `a02e8a0` nos dois clones. Deploy real no EasyPanel fica por conta do usuário (não é ação que eu executo).

**Pendência à parte, não tocada:** repo frontend tinha (antes desta tarefa) o ponteiro do submodule `server_delivery` já desatualizado/sujo (apontando pro merge de `fix/fechar-caixa-libera-mesa`, não commitado no repo pai) — deixei como estava, não commitei junto pra não misturar tarefas. Precisa resolver separado (ver [[deliveryhub_dois_clones_server_delivery]]).

**Why:** cliente presencial pergunta status/tempo do pedido ao garçom; hoje o portal do garçom só alerta quando item fica pronto, sem visão da fila.

**How to apply:** antes de mergear, pedir pro usuário testar localmente (rodar `server_delivery` submodule + frontend), depois sincronizar o clone standalone (`DEV/server_delivery`) via `git pull` antes de subir pra VPS/produção, seguindo [[deliveryhub_dois_clones_server_delivery]]. Branch em ambos repos: `feat/garcom-fila-cozinha`.
