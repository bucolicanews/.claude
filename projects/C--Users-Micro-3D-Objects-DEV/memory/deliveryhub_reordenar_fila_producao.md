---
name: deliveryhub_reordenar_fila_producao
description: "Reordenar itens na fila \"Aguardando Preparo\" de /restaurante/producao — MERGEADO+PUSHADO ambos repos+Cloud, TESTADO"
metadata: 
  node_type: memory
  type: project
  originSessionId: 17cb9c8e-5314-429b-9d0e-35fee819078f
  modified: 2026-08-02T20:30:58.148Z
---

Setas cima/baixo no card de item (coluna "Aguardando Preparo" da Linha de Produção), dono adianta ou atrasa pedido na fila do setor trocando posição com vizinho.

**Implementação:**
- Coluna nova `ordem_fila` (integer, nullable) em `order_items` — nulo = ordena por `enviado_em` (comportamento antigo); setado tem prioridade.
- Endpoint `PATCH /restaurante/kds/itens/:id/mover` com body `{ direcao: 'cima' | 'baixo' }` — `moverPosicaoItem` em `restaurante.service.ts`. Resequencia `ordem_fila` de TODOS os itens "enviado" do setor a cada swap (evita mistura de itens numerados com null).
- `GET /restaurante/kds` ordena por `ordem_fila asc nulls last, enviado_em asc`.
- Frontend: `src/pages/restaurante-producao/index.jsx`, botões só aparecem pra `item.status === 'enviado'`, desabilitados nas pontas da fila.

**Why:** dono queria poder priorizar um pedido manualmente (ex. cliente esperando mais, prato mais rápido) sem depender só da ordem de chegada.

**How to apply:** se aparecer bug de fila fora de ordem em Cozinha/Bar (não só Produção), lembrar que esses telas compartilham o mesmo GET /kds — a ordenação por ordem_fila vale pra todas elas, não só Produção.

Status: MERGEADO+PUSHADO em ambos repos (main), migration aplicada em local E Supabase Cloud via `db push --linked`. TESTADO manualmente pelo usuário. Deploy EasyPanel CONFIRMADO funcionando em produção (2026-08-02).
