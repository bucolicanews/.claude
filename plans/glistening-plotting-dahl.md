# Relatórios gerenciais: rankings de produto e garçom

## Contexto

Usuário quer responder, direto nos relatórios, perguntas gerenciais que hoje exigem olhar a lista inteira e comparar manualmente:

1. Produto mais vendido no período
2. Maior venda (comanda/pedido) em um período
3. Produto que menos vendeu
4. Produto com maior lucratividade
5. Ranking de garçom: quem vendeu mais, quem ganhou mais gorjeta, produto favorito de cada garçom, tudo filtrável por período

Decisões já tomadas com o usuário:
- Lucratividade = lucro total em R$ (não margem %).
- "Qual período vendeu mais" = o usuário escolhe o período no filtro já existente (dia/mês/ano/período) e vê o ranking daquele recorte — **sem** comparativo automático entre sub-períodos (fica pra uma iteração futura se pedirem).
- Os rankings entram **dentro das abas/páginas já existentes** (`Produtos.jsx`, `Garcom.jsx`, `Financeiro.jsx`), não uma página nova.

A infra de filtro por período (`FiltroPeriodo.jsx` + `utils/relatorioPrint.js`), impressão e export JSON já existe e é reaproveitada sem mudança.

## O que já existe (reaproveitar)

- `server_delivery/src/restaurante/restaurante.service.ts`:
  - `getRelatorioProdutos(restaurantId, de, ate)` (linha ~1930) já retorna `vendas: [{product_id, name, quantidade_vendida, receita, custo_total, lucro}]` — só falta ordenar certo e destacar os extremos. `lucro_total`/`receita_total` já calculados.
  - `getRelatorioGarcom(restaurantId, de, ate)` (linha ~1726) já retorna `garcons: [{garcom_id, nome, total_vendido, total_comissao, total_gorjeta, comandas_abertas, comandas_pendentes, repasse}]` e `vendas: [{garcom_id, garcom_nome, data, total, gorjeta, ...}]` — falta breakdown por produto.
  - `getRelatorio(restaurantId, de, ate)` (linha ~1561) já retorna `pedidos` (com `total`) — dá pra extrair "maior venda" sem tocar no backend.
- Frontend: `src/pages/restaurante-relatorios/Produtos.jsx` (abas `vendas`/`lucro` já existem mas não ordenam pelo que interessa), `Garcom.jsx` (tabela já lista tudo, sem ranking/ordenação), `Financeiro.jsx` (já tem `dados.pedidos`).

## Mudanças

### 1. Backend — só 1 adição: produto favorito por garçom

Em `getRelatorioGarcom` (`server_delivery/src/restaurante/restaurante.service.ts`), depois que `pedidos` (canal presencial, período, com garçom) já foi buscado:
- Filtrar `pedidosPagos = pedidos.filter(p => p.status === 'paga')` e pegar os `order_id`s.
- Buscar `order_items` desses pedidos (mesmo padrão de `getRelatorio`, linha ~1604: `select('id, order_id, product_id, quantity, unit_price')`).
- Buscar nomes dos produtos envolvidos (`products` por `id in productIds`, mesmo padrão `prodMap`).
- Agregar por `(garcom_id via order_id → pedido.garcom_id, product_id)`: `quantidade` e `receita`.
- Anexar em cada linha de `porGarcom`: `produtos: [{product_id, name, quantidade, receita}]` ordenado desc por `quantidade`, cortado no top 5.
- Retorno final ganha esse campo extra em cada garçom — não quebra nada que já consome esse endpoint.

Nenhuma outra rota/serviço muda. `getRelatorioProdutos` e `getRelatorio` não precisam de alteração no backend — os rankings 1/2/3/4 são derivados no frontend a partir do que já vem.

### 2. Frontend — `restaurante-relatorios/Produtos.jsx`

- Cards de destaque no topo (junto dos KPIs que já existem — grid de 8 cards): adicionar 3 novos cards clicáveis (mesmo padrão dos atuais) — **Mais Vendido**, **Menos Vendido**, **Mais Lucrativo** — cada um mostrando nome do produto + valor (qtd ou R$), calculados com `useMemo` a partir de `dados.vendas`:
  - Mais vendido: `[...vendas].sort((a,b) => b.quantidade_vendida - a.quantidade_vendida)[0]`
  - Menos vendido: mesma lista ordenada asc (considerar excluir produtos com `quantidade_vendida === 0` do "menos vendido" se já existem em "Sem Giro" — não duplicar sentido; usar o menor valor **> 0** ou deixar claro que 0 conta como "não vendeu").
  - Mais lucrativo: `sort((a,b) => b.lucro - a.lucro)[0]`.
  - Clicar no card muda pra aba `vendas` ou `lucro` já ordenada (ver abaixo).
- Aba **Vendas no Período** (`aba === 'vendas'`): ordenar `listaVendas` por `quantidade_vendida` desc por padrão (hoje herda a ordem de `receita` do backend). Adicionar toggle simples "Maior → Menor / Menor → Maior" no cabeçalho da tabela (estado local `ordemVendas`).
- Aba **Lucro no Período** (`aba === 'lucro'`): ordenar `listaLucro` por `lucro` desc por padrão (hoje não ordena). Mesmo toggle de direção.
- `QtdFiltroBar` (filtro por quantidade, já existe) continua funcionando igual, é aplicado depois da ordenação.
- Print/export (`buildPrintHtml`, `exportarJson`) já iteram sobre a lista recebida — como a ordenação agora é client-side antes de renderizar, passar a lista já ordenada pra essas funções também (hoje `buildPrintHtml` recalcula a lista internamente a partir de `dados` — ajustar pra aceitar a lista final já ordenada, que é o padrão que `onImprimir` já usa via `listaOverride`).

### 3. Frontend — `restaurante-relatorios/Garcom.jsx`

- Cards de destaque no topo (já existe grid de 4 KPIs — Total Vendido/Comissão/Gorjeta/A Receber): adicionar 2 cards — **Quem Vendeu Mais** e **Quem Ganhou Mais Gorjeta** — nome do garçom + valor, via `useMemo` sobre `garconsFiltrados`.
- Tabela principal: ordenar por `total_vendido` desc por padrão (hoje segue a ordem de `garcons` do banco). Adicionar toggle de ordenação (por venda / por gorjeta / por comissão), reaproveitando o mesmo padrão de header clicável.
- Nova coluna/expansão por garçom: "Produto favorito" — mostra o item top-1 do novo campo `g.produtos` retornado pelo backend (nome + qtd). Se quiser ver o top 5 completo, um popover/tooltip simples ao passar o mouse ou um botão "ver mais" que expande uma lista inline (sem modal novo, pra não pesar) — usar o padrão de expandir linha que a tabela de `HistoricoCaixasPanel.jsx` (financeiro) já usa como referência de UX.
- Adicionar campo de busca por nome (input de texto), complementando o `<select>` de filtro por garçom que já existe — mesmo padrão do `busca` em `Produtos.jsx`.

### 4. Frontend — `restaurante-relatorios/Financeiro.jsx`

- Nova seção "Maiores Vendas do Período": lista top 10 de `dados.pedidos` ordenado desc por `total` (ou por `total_geral` se quiser incluir gorjeta+taxa, seguir o mesmo campo já usado no resto do relatório). Mostrar: posição, cliente/mesa, valor, data/hora, forma de pagamento — reaproveitando o componente de linha de tabela que a aba "Detalhamento das Vendas" do `Garcom.jsx` já usa como referência visual.
- Sem mudança de filtro — usa o mesmo `dados` que a página já carrega.

### 5. Estilo / dark mode

Essas telas já foram migradas pro dark mode nesta sessão (grupo 4) — qualquer elemento novo (cards, toggle de ordenação, badge de ranking) precisa nascer já com os pares `dark:` consistentes com o resto do arquivo (tokens já usados: `text-[#18181B] dark:text-[#F4F4F5]`, `bg-white dark:bg-[#27272A]`, `border-[#E4E4E7] dark:border-[#3F3F46]`, cores semânticas `bg-green-50 dark:bg-green-950/40` etc. — mesmo padrão aplicado no resto do arquivo).

## Arquivos tocados

- `server_delivery/src/restaurante/restaurante.service.ts` (1 função estendida: `getRelatorioGarcom`)
- `src/pages/restaurante-relatorios/Produtos.jsx`
- `src/pages/restaurante-relatorios/Garcom.jsx`
- `src/pages/restaurante-relatorios/Financeiro.jsx`

Nenhuma migration de banco necessária (não cria tabela/coluna nova, só agrega dados existentes). Nenhuma mudança em `restauranteService.js` (endpoints e assinaturas continuam iguais, só o payload de `getRelatorioGarcom` ganha um campo a mais).

## Branch e ordem de execução

Branch nova a partir de `main` (ex: `feat/relatorios-gerenciais`), seguindo o padrão já usado nesta sessão. Ordem sugerida:
1. Backend: estender `getRelatorioGarcom` com `produtos` por garçom.
2. `Produtos.jsx`: cards de destaque + ordenação correta nas abas vendas/lucro.
3. `Garcom.jsx`: cards de destaque + ordenação + produto favorito + busca por nome.
4. `Financeiro.jsx`: seção "Maiores Vendas".
5. Commit por etapa (padrão já usado: commit após cada mudança validada).

## Verificação

- Backend: como o usuário roda o servidor manualmente (não subo proativamente), depois da mudança em `restaurante.service.ts` pedir pra reiniciar o backend local antes de testar (mudança em arquivo `.ts` não recarrega sozinha em processo já rodando — mesmo gotcha já registrado em memória).
- `npx vite build --mode development` no frontend depois de cada arquivo mexido, pra pegar erro de sintaxe cedo (mesmo fluxo usado no retrofit de dark mode desta sessão).
- Teste manual no navegador em `/restaurante/relatorios/produtos`, `/restaurante/relatorios/garcom` e `/restaurante/relatorios/financeiro`: rodar com dados reais de pelo menos um período com vendas, conferir que os cards de destaque batem com o que dá pra conferir manualmente na tabela, testar toggle de ordenação, testar em dark mode.
