# Aba "Cozinha" no painel do garçom — fila de preparo + tempo médio

## Contexto

Hoje, quando um cliente presencial pergunta ao garçom "como está meu pedido?" ou "quanto tempo falta?", o garçom não tem visibilidade nenhuma da fila da cozinha dentro do próprio portal (`GarcomPortal`) — só existe alarme sonoro quando um item fica pronto (`itens-prontos`). A tela de cozinha (`restaurante-cozinha/index.jsx`) já tem toda a lógica de fila/timers, mas é uma tela separada (dono/cozinha), não acessível ao garçom.

Pedido: nova aba no painel do garçom mostrando os itens em preparo (e aguardando) numa lista ordenada, com posição na fila, tempo decorrido por item, e tempo médio de preparo do dia — pra o garçom responder o cliente sem sair do próprio portal.

Decisões confirmadas com o usuário:
- **Granularidade:** por item (`order_items`), não agrupado por comanda — reaproveita o modelo de dados existente sem lógica nova de agregação.
- **Escopo:** restaurante inteiro (todas as mesas/comandas), não só as do garçom logado — qualquer garçom pode responder sobre qualquer mesa.
- **Tempo médio:** média de `pronto_em - preparando_em` dos itens finalizados **hoje**, nesse restaurante.

## Backend (`server_delivery`)

Arquivo: `src/salao/salao.service.ts`

Novo método `filaCozinha(restaurantId: number)`, seguindo o padrão de `itensProntos` (linha 353) e o filtro `canal='presencial'` já usado em `minhasComandas`/`itensProntos` (mais preciso que a heurística `ehSalao` de `getKdsSetor`):

1. **Fila** — busca `order_items` com `status in ('enviado','preparando')`, via join com `orders` filtrado por `restaurant_id`, `canal = 'presencial'`, `status in ('aberta','fechada_garcom')`, ordenado por `enviado_em ascending`. Select incluindo `mesas(numero, nome)` e `products(name)` (mesmo padrão de `getKdsSetor`, linha 782, e `itensProntos`, linha 356/368). Campos retornados por item: `item_id, order_id, numero_comanda, mesa, cliente_mesa_nome, product_name, quantity, status, enviado_em, preparando_em`.

2. **Tempo médio** — busca `order_items` com `status = 'pronto'`, `preparando_em` e `pronto_em` não nulos, `pronto_em >= início do dia (hora local do servidor)`, mesmo join/filtro de restaurante+canal presencial. Calcula em JS a média de `(pronto_em - preparando_em)` em segundos. Retorna `null` se não houver amostras.

Retorno do método: `{ itens: [...], tempoMedioPreparoSegundos: number|null, amostras: number }`.

Arquivo: `src/salao/salao.controller.ts` — novo endpoint dentro do `SalaoController` existente (já tem `@UseGuards(GarcomGuard)` a nível de classe, então herda a autenticação automaticamente):

```ts
@Get('fila-cozinha')
filaCozinha(@Req() req: any) {
  return this.service.filaCozinha(req.garcomRestaurantId);
}
```

**Aplicar a mesma mudança nos dois clones do backend** (submodule `deliveryhub_white_label/server_delivery` onde o código é escrito, e depois `git pull` no clone standalone `DEV/server_delivery` antes de testar/subir — ver regra de sincronização já conhecida).

## Frontend (`deliveryhub_white_label`)

**`src/services/garcomService.js`** — adicionar `getFilaCozinha()`, chamando `GET /fila-cozinha` via `garcomFetch` (mesmo padrão de `getItensProntos`).

**`src/pages/garcom-portal/index.jsx`**:

- Novo botão de aba "Cozinha" ao lado de "Mesas"/"Minhas comandas" (linhas 938-949), `aba === 'cozinha'`.
- Novo estado `[filaCozinha, setFilaCozinha]` e `[tempoMedio, setTempoMedio]` em `GarcomHome`.
- Polling: reaproveitar o mesmo `useEffect` de polling que já existe para `itens-prontos` (linhas 875-894, intervalo de 15s) — adicionar a chamada de `getFilaCozinha()` dentro do mesmo `checar()`, evitando um segundo timer solto.
- Novo componente `FilaCozinha` (mesmo arquivo, junto dos outros subcomponentes como `ComandaDetalhe`):
  - `const now = useNowTick();` (`src/hooks/useNowTick.js`, já existe, mesmo hook usado em `restaurante-cozinha/index.jsx:290`).
  - Topo: card com "Tempo médio de preparo hoje: `formatDuracao(tempoMedioPreparoSegundos * 1000)`" (util `src/utils/formatDuracao.js`, já existe) — ou "Sem dados ainda hoje" se `tempoMedioPreparoSegundos` for `null`.
  - Lista dividida em duas seções por `status`:
    - **"Aguardando"** (`status === 'enviado'`): ordenada por `enviado_em`, numerada (1º, 2º, 3º...) via índice do array — é a posição "pra entrar em preparo" que o usuário pediu.
    - **"Em preparo"** (`status === 'preparando'`): ordenada por `preparando_em`, numerada (1º, 2º...) e com timer ao vivo `formatDuracao(now - new Date(item.preparando_em))`.
  - Cada linha mostra: produto + quantidade, mesa/comanda (`item.mesa ?? \`Comanda #${item.numero_comanda}\``), cliente se houver.
  - Itens que já ficaram `pronto` somem da lista naturalmente (a query do backend só traz `enviado`/`preparando`) — se o garçom não encontrar o item na fila, é sinal de que já está pronto (cobre o terceiro caso do pedido: "já está pronto"), sem precisar de uma seção extra pra isso (já existe alarme + aba de itens prontos pra esse caso).

## Verificação

- Rodar backend (`server_delivery`, submodule) e frontend localmente.
- Abrir portal do garçom (`/garcom/:loginKey`), enviar itens de uma comanda pra cozinha, confirmar que aparecem em "Aguardando" com posição correta.
- Na tela da cozinha (`/restaurante/cozinha`), clicar "Iniciar Preparo" num item e conferir que ele migra pra "Em preparo" no portal do garçom, com timer contando.
- Marcar item como "Pronto" na cozinha e confirmar que ele some da fila do garçom.
- Marcar 2-3 itens como prontos e conferir que "Tempo médio de preparo hoje" aparece com valor plausível.
- Testar com duas comandas de mesas diferentes pra confirmar que a fila é do restaurante inteiro, não só do garçom logado.
