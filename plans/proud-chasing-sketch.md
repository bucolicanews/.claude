# Conferências: relatório de motoboy + aba Financeiro no portal do motoboy

## Contexto

Hoje o menu lateral do restaurante tem "Relatórios", com sub-relatórios de Garçom, Financeiro e Produtos. O relatório de Garçom já resolve um problema real: mostra quanto cada garçom vendeu/comissionou, permite conferir venda por venda, e registrar o repasse (pagamento) dividido em dinheiro/PIX, com baixa automática no caixa e possibilidade de estorno.

O motoboy não tem nada equivalente — o dono não tem como conferir quanto cada motoboy ganhou num período nem registrar que já pagou. Do lado do motoboy, já existe uma aba "Ganhos" no portal (`/motoboy`) mas ela soma tudo desde sempre, sem noção de "hoje" ou "por dia", o que não ajuda o motoboy a acompanhar a produção diária.

Este plano: (1) renomeia "Relatórios" para "Conferências" no menu, (2) cria um relatório de Motoboy espelhando exatamente o de Garçom (incluindo repasse com caixa/estorno), e (3) transforma a aba "Ganhos" do motoboy em "Financeiro", com um bloco de "hoje" e um histórico por dia.

Decisão já validada com o usuário: repasse completo (igual garçom), aba "Financeiro" substitui "Ganhos" (não duplica), sem etapa de conferência/aceite pelo motoboy (isso fica só do lado do garçom).

## Descobertas relevantes do código existente

- O padrão a copiar é `src/pages/restaurante-relatorios/Garcom.jsx` + `restaurante.service.ts` (`getRelatorioGarcom`/`registrarRepasseGarcom`/`estornarRepasseGarcom`, linhas 2159-2410) + migração `supabase/migrations/20260727190000_garcom_repasses.sql`.
- **Motoboys não são presos a 1 restaurante** — existe afiliação N:N em `motoboy_estabelecimentos` (`motoboy_id, restaurant_id, status: pendente|aceito|recusado|removido`). Pra listar "os motoboys deste restaurante" tem que filtrar essa tabela por `restaurant_id` + `status='aceito'`, não `motoboys.restaurant_id` direto (esse campo é legado/1:1 antigo).
- `motoboy_comissoes` (migração `20260713000006`) já tem colunas `status ('pendente'|'pago')` e `pago_em` **nunca usadas** — dá pra aproveitar no repasse do motoboy em vez de deixar mortas.
- `adicionarSaida` / `removerSaidaPorCriadoEm` já existem em `restaurante.service.ts` (linhas ~1755/1790) e são reaproveitados tal qual pro caixa do motoboy.
- Aba "Ganhos" atual: `src/pages/motoboy-portal/index.jsx`, componente `AbaGanhos` (linhas 247-307), state de aba não é roteado (`useState('pedidos'|'estabelecimentos'|'ganhos'|'perfil')`).

## Parte 1 — Renomear "Relatórios" → "Conferências"

Troca de label pura, sem mudar rotas:
- `src/config/restauranteNavLinks.js:3` — `label: 'Relatórios'` → `'Conferências'`.
- `src/pages/restaurante-relatorios/RelatorioNav.jsx:7` — `'Menu Relatórios'` → `'Menu Conferências'`.
- `src/pages/restaurante-relatorios/index.jsx:38` — `title="Relatórios"` → `title="Conferências"`.

(Não mexer em `restaurante-dashboard/RelatorioPanel.jsx:171` — é um título de widget diferente, fora do escopo pedido.)

## Parte 2 — Relatório de Motoboy (`/restaurante/relatorios/motoboy`)

### 2.1 Migração — `supabase/migrations/20260824120000_motoboy_repasses.sql`
Mesma estrutura de `garcom_repasses`, sem `valor_gorjeta` (motoboy não recebe gorjeta):
```sql
CREATE TABLE IF NOT EXISTS public.motoboy_repasses (
  id BIGSERIAL PRIMARY KEY,
  restaurant_id BIGINT NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  motoboy_id BIGINT NOT NULL REFERENCES public.motoboys(id) ON DELETE CASCADE,
  periodo_de TIMESTAMPTZ NOT NULL,
  periodo_ate TIMESTAMPTZ NOT NULL,
  valor_comissao NUMERIC(10,2) NOT NULL DEFAULT 0,
  valor_dinheiro NUMERIC(10,2) NOT NULL DEFAULT 0,
  valor_pix NUMERIC(10,2) NOT NULL DEFAULT 0,
  caixa_id BIGINT REFERENCES public.caixas(id) ON DELETE SET NULL,
  saida_criado_em TIMESTAMPTZ,
  pago_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (motoboy_id, periodo_de, periodo_ate)
);
-- + índices (restaurant_id, motoboy_id, pago_em) + RLS owner (igual garcom_repasses)
```

### 2.2 Backend — `server_delivery/src/restaurante/restaurante.service.ts` (aplicar igual nos dois checkouts: `server_delivery` e `serer_delivery`)
Três métodos novos logo após `estornarRepasseGarcom` (linha ~2410):

- **`getRelatorioMotoboy(restaurantId, de, ate)`**: semeia a lista a partir de `motoboy_estabelecimentos` (`restaurant_id=X, status='aceito'`, join `motoboys(id,name)`) — inclui motoboys bloqueados (podem ter comissão pendente de pagar), só exclui quem nunca teve afiliação aceita. Busca `motoboy_comissoes` do período (`restaurant_id`, `criado_em` entre `de`/`ate`). Agrega por motoboy: `entregas` (contagem), `total_frete_repassado`, `total_adicional`, `total_comissao` (soma de `comissao_valor`). Monta lista `entregas` detalhada (pedido, data, tipo, distância, frete, adicional, comissão) pra tabela de conferência. Cruza com `motoboy_repasses` do período exato pra saber quem já foi pago. **Sem** seção de turnos — motoboy não tem esse conceito. Retorna `{ motoboys, entregas }`.
- **`registrarRepasseMotoboy(restaurantId, motoboyId, { de, ate, valor_comissao, valor_dinheiro?, valor_pix? })`**: valida afiliação aceita; valida soma dinheiro+pix ≈ valor_comissao; se dinheiro > 0, chama `adicionarSaida` (mesmo padrão do garçom); insere em `motoboy_repasses`; trata `23505` como `ConflictException` (já pago esse período); em erro pós-saída, reverte a saída. **Depois do insert dar certo**, atualiza em lote (best-effort, não derruba a request se falhar) as linhas de `motoboy_comissoes` daquele motoboy+período pra `status='pago', pago_em=NOW()`.
- **`estornarRepasseMotoboy(restaurantId, repasseId)`**: busca o repasse, reverte a saída de caixa se houver, apaga a linha, e (best-effort) reverte as `motoboy_comissoes` do período de volta pra `status='pendente', pago_em=NULL`.

### 2.3 Backend — `server_delivery/src/restaurante/restaurante.controller.ts` (ambos checkouts)
Logo após o bloco de `estornarRepasseGarcom` (linha ~373):
```ts
@Get('relatorio/motoboy')
relatorioMotoboy(@Req() req, @Query('de') de, @Query('ate') ate) {
  return this.service.getRelatorioMotoboy(req.restaurantId, de, ate);
}
@Post('relatorio/motoboy/:motoboyId/repasse')
registrarRepasseMotoboy(@Req() req, @Param('motoboyId', ParseIntPipe) motoboyId, @Body() body) {
  return this.service.registrarRepasseMotoboy(req.restaurantId, motoboyId, body);
}
@Delete('relatorio/motoboy/repasse/:repasseId')
estornarRepasseMotoboy(@Req() req, @Param('repasseId', ParseIntPipe) repasseId) {
  return this.service.estornarRepasseMotoboy(req.restaurantId, repasseId);
}
```

### 2.4 Frontend — `src/services/restauranteService.js`
Após `estornarRepasseGarcom` (linha ~188):
```js
export const getRelatorioMotoboy = (de, ate) => apiFetch(`/relatorio/motoboy?de=${encodeURIComponent(de)}&ate=${encodeURIComponent(ate)}`);
export const registrarRepasseMotoboy = (motoboyId, data) => apiFetch(`/relatorio/motoboy/${motoboyId}/repasse`, { method: 'POST', body: JSON.stringify(data) });
export const estornarRepasseMotoboy = (repasseId) => apiFetch(`/relatorio/motoboy/repasse/${repasseId}`, { method: 'DELETE' });
```

### 2.5 Frontend — nova página `src/pages/restaurante-relatorios/Motoboy.jsx`
Cópia estrutural de `Garcom.jsx` (filtro de período via `FiltroPeriodo`, tabela-resumo, tabela de detalhamento, modal de repasse com split dinheiro/PIX, estorno, impressão via `relatorioPrint.js`), com as diferenças:
- Sem seção "Sessões do período" (turnos) — não existe pro motoboy.
- Sem "produto favorito" / coluna expansível.
- Colunas do resumo: Motoboy, Entregas, Frete Repassado, Adicional, Comissão Total, Repasse.
- Colunas do detalhamento: Data/Hora, Motoboy, Pedido, Tipo, Distância, Frete, Adicional, Comissão.
- Modal de repasse: só `valor_comissao` (sem campo gorjeta).

### 2.6 Wiring
- `src/pages/restaurante-relatorios/RelatorioNav.jsx` — adicionar `{ label: 'Motoboy', path: '/restaurante/relatorios/motoboy' }` em `SUBLINKS`.
- `src/pages/restaurante-relatorios/index.jsx` — novo card no array `RELATORIOS` (ícone `Bike`, cor não usada ainda pelas outras 3 — ex. amber).
- `src/Routes.jsx` — import `RestauranteRelatorioMotoboy from './pages/restaurante-relatorios/Motoboy'` (mesmo padrão da linha 52) + rota `/restaurante/relatorios/motoboy` (mesmo padrão da linha 134).

## Parte 3 — Aba "Financeiro" no portal do motoboy

### 3.1 Backend — `server_delivery/src/motoboy/motoboy.service.ts` (ambos checkouts)
- `ganhosResumo(motoboyId)`: passa a buscar também `criado_em`; calcula janela de "hoje" (mesmo padrão de corte de data usado em `relatorioFretes`) e devolve `hoje: { entregas, total }` junto com `resumo`/`total_geral` já existentes.
- Novo método `ganhosPorDia(motoboyId)`: busca `motoboy_comissoes` dos últimos ~14 dias, agrupa por dia (mesmo padrão `por_dia` de `relatorioFretes`, linhas ~1886-1894), retorna `{ por_dia: [{ dia, entregas, total }] }` mais recente primeiro.

### 3.2 Backend — `server_delivery/src/motoboy/motoboy-portal.controller.ts` (ambos checkouts)
Novo endpoint após `ganhos/historico`:
```ts
@Get('ganhos/por-dia')
ganhosPorDia(@Req() req) { return this.service.ganhosPorDia(req.motoboyId); }
```

### 3.3 Frontend — `src/services/motoboyService.js`
```js
export const getGanhosPorDia = () => motoboyFetch('/ganhos/por-dia');
```

### 3.4 Frontend — `src/pages/motoboy-portal/index.jsx`
- Renomear a aba: `id: 'ganhos'` → `id: 'financeiro'`, `label: 'Ganhos'` → `'Financeiro'` (no array de abas ~840-854 e no bloco condicional de render ~858-966, mais o botão de perfil se referenciar o id em algum lugar).
- `AbaGanhos` (renomear pra `AbaFinanceiro`): adiciona `getGanhosPorDia()` ao `Promise.all` inicial; novo bloco "Hoje" (mesmo estilo do card gradiente já usado pro total, mostrando entregas + total do dia) antes/junto do card "Total ganho"; nova lista "Produção diária" (mesmo padrão visual de item de lista já usado em "Por estabelecimento"/"Histórico") logo abaixo, usando `porDia`.
- Sem filtro de período nem botão de conferência/aceite — só visualização.

## Ordem de implementação sugerida
1. Migração `motoboy_repasses`.
2. Backend do relatório (service + controller) — nos dois checkouts.
3. Frontend do relatório (service + página + wiring).
4. Rename "Conferências" (independente, pode ser feito em qualquer ponto).
5. Backend da aba Financeiro (service + controller) — nos dois checkouts.
6. Frontend da aba Financeiro (service + `AbaFinanceiro` + rename da aba).

## Verificação
- `http://localhost:4028/restaurante/relatorios/motoboy`: conferir tabela por motoboy, abrir detalhamento, registrar um repasse (split dinheiro/PIX) e confirmar que aparece uma saída no caixa; estornar e confirmar que a saída some; tentar repassar o mesmo período de novo e confirmar erro de conflito (409).
- `http://localhost:4028/motoboy` → aba "Financeiro": confirmar que "Hoje" bate com uma entrega recém-concluída em teste, e que "Produção diária" lista os últimos dias corretamente.
- Conferir que os dois checkouts do backend (`server_delivery` e `serer_delivery`) recebem exatamente as mesmas mudanças de código.
