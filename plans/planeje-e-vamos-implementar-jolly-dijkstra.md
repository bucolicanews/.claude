# Impedir perda de conferência/histórico ao excluir garçom

## Contexto

Incidente real: um operador excluiu garçom(ns) e as "conferências" (fechamentos de turno de trabalho, com vendas/gorjeta/comissão apuradas) desse garçom desapareceram junto — dado de auditoria/financeiro que não deveria poder sumir.

**Causa raiz confirmada:** `GarconsService.remover()` (`server_delivery/src/salao/garcons.service.ts:129`) faz `DELETE FROM garcons` direto, sem nenhuma validação de histórico. Três tabelas têm FK pra `garcons(id)` com `ON DELETE CASCADE`:

| Tabela | O que guarda |
|---|---|
| `garcom_turnos` | A "conferência" em si — campo `resumo` (JSONB) congela vendas/gorjeta/comissão do turno no fechamento (`GarcomTurnoService.encerrarTurno`) |
| `garcom_comissoes_lancamentos` | Lançamento de comissão por comanda fechada |
| `garcom_repasses` | Registro de repasse (gorjeta+comissão) já pago ao garçom |

Excluir o garçom apaga essas três em cascata — perda total e irreversível via SQL padrão do Postgres, sem erro nenhum pro usuário. (`orders.garcom_id` é `SET NULL`, então a comanda em si sobrevive, só perde o vínculo.)

**Precedente já existe no projeto** pra exatamente esse tipo de problema: `MotoboyService.excluirPeloRestaurante` (`server_delivery/src/motoboy/motoboy.service.ts`) bloqueia a exclusão (`400 BadRequestException`) se o motoboy já tem `motoboy_comissoes`, orientando "bloqueie em vez de excluir, pra não perder o histórico". O garçom já tem exatamente esse mecanismo de "bloquear" pronto e funcionando — a coluna `garcons.ativo` já existe, já é editável via `PATCH` (`atualizar()`), e o frontend (`restaurante-garcons/index.jsx`) já tem um botão "Ativar/Desativar" ao lado do "Remover". Só falta a exclusão respeitar o mesmo cuidado que o motoboy já tem.

## Abordagem

**Bloquear a exclusão em vez de permitir que ela apague dado financeiro.** Replicar o padrão do motoboy: se o garçom tem qualquer `garcom_turnos`, `garcom_comissoes_lancamentos`, `garcom_repasses` ou `orders` associados, `remover()` recusa com uma mensagem clara direcionando pra "Desativar" (que já existe, não apaga nada, só tira o garçom da lista de ativos/login). Só garçom sem nenhum histórico continua podendo ser excluído de verdade.

Não vou mexer nas FKs (`ON DELETE CASCADE` → `SET NULL`) nem criar colunas de snapshot de nome — isso teria impacto em RLS (`garcom_comissoes_lancamentos` não tem `restaurant_id` próprio, só chega no restaurante via join com `garcons`; um `garcom_id` nulo quebraria a política de RLS dessa tabela) e é uma frente bem maior, mais arriscada, pra um ganho marginal já que o bloqueio de exclusão sozinho fecha o buraco por completo daqui pra frente (a exclusão nunca mais vai poder acontecer tendo histórico, então o cenário "FK em cascata apaga conferência" simplesmente deixa de ser possível). Se ainda assim quiser essa camada extra de proteção depois, fica como frente separada.

**Sobre o dado já perdido no incidente:** `garcom_turnos`/`garcom_comissoes_lancamentos`/`garcom_repasses` já deletados não têm como voltar por código — só recuperação via backup/point-in-time restore do Supabase, se existir um backup de antes da exclusão (ação fora do escopo desse fix, é operação no painel do Supabase, não código).

## Implementação

### Backend — `server_delivery/src/salao/garcons.service.ts`

Em `remover(id, restaurantId)`, antes do `.delete()`: checar (em paralelo, `count: 'exact', head: true`) se existe qualquer linha em `garcom_turnos`, `garcom_comissoes_lancamentos`, `garcom_repasses` ou `orders` com esse `garcom_id`. Se qualquer count > 0, `throw new BadRequestException('Este garçom já tem histórico de turnos/vendas/comissão — desative em vez de excluir, pra não perder a conferência.')`. Mesma mensagem/estilo do motoboy.

Replicar a mudança nos dois checkouts de backend (`deliveryhub_white_label/server_delivery` e `serer_delivery`, hoje idênticos).

### Frontend — `src/pages/restaurante-garcons/index.jsx`

`remover()` (linha 104) hoje não tem `try/catch` — se o backend passar a lançar 400, a promise rejeitada não mostra nada pro usuário (falha silenciosa). Adicionar tratamento de erro (estado local `erro`/`alert`, mesmo padrão simples já usado no `NovoGarcomForm` logo acima) pra exibir a mensagem do backend e o usuário saber que precisa clicar "Desativar" em vez de "Remover".

### Verificação

1. `tsc --noEmit` no backend, `vite build` no frontend.
2. Manual: tentar excluir um garçom que já fechou pelo menos um turno (ou tem comissão/repasse/pedido) → deve vir erro claro, garçom continua existindo. Tentar excluir um garçom novo sem nenhum histórico → deve excluir normalmente (comportamento atual preservado pra esse caso). Desativar um garçom com histórico → deve funcionar sem erro (fluxo já existente, não deve ter sido afetado).
3. Sincronizar os dois checkouts de backend (`server_delivery`/`serer_delivery`), commit + push nos três repos (sem migration nova, nada pra aplicar em produção via `db push --linked`).
