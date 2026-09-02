# Pagamento manual (sem PagBank) no delivery

## Contexto

Hoje o restaurante só tem um jeito de cobrar pedidos de delivery online: a integração PagBank (`serer_delivery/src/pagamentos/`), que gera PIX via API ou tokeniza cartão. Isso já funciona, mas exige que o dono configure token PagBank — e nem todo restaurante quer/consegue usar isso. Além disso, cartão hoje nem está integrado no checkout do cliente (o backend suporta, o frontend não chama), e "dinheiro" já é resolvido manualmente na entrega.

O pedido: dar ao dono um **toggle explícito** em Configurações — "usar API PagBank" vs "receber manualmente" — pra restaurantes que preferem cobrar por fora do PagBank. Em modo manual:
- O checkout do cliente **não abre nenhuma tela de pagamento online** (nem PIX via API, nem cartão) — o cliente só escolhe a forma de pagamento e o pedido segue.
- A entrega continua sendo feita pelo motoboy (não pelo dono) — é ele quem efetivamente recebe o pagamento na porta, usando o app.
  - **PIX**: o motoboy já tem esse mecanismo pronto (`EntregaBarcode.jsx`, etapa `pix`) — gera um QR estático a partir da chave PIX cadastrada em Configurações (`payment_config.chave_pix`), sem depender da API do PagBank. Só falta tornar o comprovante fotográfico **obrigatório** (hoje é opcional).
  - **Dinheiro**: fluxo já existente (troco/valor exato) — sem mudanças.
  - **Cartão** (crédito/débito): **não existe hoje** nenhuma etapa de cartão na entrega. O motoboy leva a maquininha, cobra, e deve bater uma foto obrigatória do comprovante — e o app deve informar a taxa do cartão (reaproveitando `restaurants.taxa_cartao_percentual`, que já existe e já é configurável em Configurações, hoje usado só pelo módulo Salão) antes de fechar.
- No painel do dono (pedidos de delivery), deve existir um botão **"Marcar como pago"** pro caso do cliente ter combinado o pagamento por fora (contato direto) — isso deve **pular a etapa de cobrança do motoboy** na entrega (ele só confirma a entrega, sem pedir pagamento de novo).

Decisões já validadas com o usuário (mensagens 1 e 2, e correção explícita na 2ª): a entrega continua sendo do motoboy (não do dono/"entrega própria" — essa tela fica fora do escopo). PIX usa a chave cadastrada (mecanismo já existente). Cartão é fechado pelo motoboy com a maquininha física, com foto obrigatória do comprovante e informando a taxa do cartão ao cliente.

## Investigação já feita (não re-explorar — usar como verdade)

- **PagBank**: `serer_delivery/src/pagamentos/{pagbank.client,pagamentos.service,pagamentos.controller}.ts`. Tabela `pagamentos` (migration `20260605000000_add_pagamentos.sql`) — `tipo IN ('pix','credit_card','debit_card')`, só PagBank, não inclui `cash`/manual. Config fica em `restaurants.payment_config` JSONB (`pagbank_token`, `chave_pix`, `pagbank_sandbox`, `taxa_cartao_percentual` **não** — esse é campo próprio, ver abaixo), nunca exposto em claro (`restaurante.service.ts:46`).
- **`restaurants.taxa_cartao_percentual`**: coluna própria (não dentro do JSONB), já existe, já editável via `GET/PATCH /restaurante/config` (`restaurante.service.ts:849,876,901,935`) e já usada pelo módulo Salão via `SalaoService.calcularTaxaCartao(restaurantId, valor, formaPagamento)` (`salao.service.ts:179-189`): `if (formaPagamento !== 'credit_card' && formaPagamento !== 'debit_card') return 0; ... return valor * percentual / 100`. **`MotoboyService` já injeta `SalaoService`** (usado em `motoboy.service.ts:616` para `registrarEntradaCaixa`) — dá pra chamar `calcularTaxaCartao` direto de lá.
- **Config do estabelecimento**: tela `deliveryhub_white_label/src/pages/restaurante-config/index.jsx`. Backend `GET/PATCH /restaurante/config` → `restaurante.service.ts` `getConfig`/`updateConfig` (~840-940). Existe também um painel admin paralelo (`serer_delivery/src/empresas/empresas.service.ts`, `getConfig`/`updateConfig` ~186-230) que edita o mesmo `payment_config` — fora de escopo, não precisa mexer.
- **Checkout do cliente**: `shopping-cart-checkout/index.jsx`. `PAYMENT_OPTIONS` linha 14. `SingleCartCheckout` recebe `restauranteId`/`restauranteSlug`/`freteMotoboy` via `location.state`/`sessionStorage('pending_cart')` (linha ~389) — não busca nenhum dado do restaurante além do ID. `handleFinalizar` (420-479): sempre `POST /api/pedidos` primeiro; se `paymentMethod==='pix'`, chama `POST /api/pagamentos/pix` e mostra `PixScreen`; se falhar, hoje já cai (acidentalmente) em navegar pro tracking sem cobrar. Cartão nunca chama `/pagamentos/cartao` (não integrado). Dinheiro nunca tenta pagamento.
- **Exposição pública do restaurante pro checkout**: `catalogo.controller.ts`, `GET /catalogo/by-domain/:host` (linha ~295) e `GET /catalogo/:slug` (linha ~313), ambos com `.select('id, name, address, logo_url, business_hours, slug, aparencia, frete_motoboy, modulo_delivery')` — já é o canal usado hoje pra levar `frete_motoboy` até o checkout (`restaurante-catalogo/index.jsx` `irParaCheckout` ~303-312, grava em `pending_cart`/`location.state`). Adicionar `pagamento_manual` nesses dois selects é reaproveitar um caminho já pronto — **não precisa endpoint novo**.
- **Painel do dono / pedidos**: `restaurante-pedidos/index.jsx`. Não existe botão "marcar como pago" nem campo `payment_status` em `orders` — status de pagamento hoje só existe implicitamente. `pedidos.service.ts` (listagem usada por esse painel) não seleciona `pago_em`/`canal` ainda.
- **Motoboy — `motoboy-portal/EntregaBarcode.jsx`** (renderizado quando `pedido.status==='out_for_delivery'`, ver `motoboy-portal/index.jsx:586-595`, que já passa `chavePix={p.restaurante?.chave_pix}`):
  - Etapas: `scan → pagamento → troco|exato|pix|pix_parcial → acao → ocorrencia`.
  - Etapa `pagamento` (171-214): "Conforme pedido", "Valor exato", e se `chavePix`: "PIX" e "Dinheiro + PIX". **Sem opção Cartão hoje.**
  - Etapa `pix` (291-333): `pixQr(valor)` gera QR estático local (`utils/pixQrCode.js`, `gerarPixPayload`/`qrCodeUrl`) a partir de `chavePix` — **é exatamente o mecanismo pedido pro PIX manual**. Foto (`comprovanteBase64`) é capturada mas **não bloqueia** o botão de confirmar (linha 322-328, `disabled={confirmando}` só).
  - `handleEntregar` (117-133): se tiver foto, `uploadComprovantePix(pedido.id, base64)` → `confirmarEntrega(pedido.id, entregaPagamento)`.
  - **Não existe nenhum gate** por "pedido já pago" — a etapa `pagamento` sempre roda pra todo pedido `out_for_delivery`, mesmo os pagos via PagBank online.
  - `motoboy.service.ts`: `meusPedidos` (488-538) seleciona `orders` com `'id, total, troco_para, status, payment_method, restaurant_id, created_at, updated_at, motoboy_lat, motoboy_lng, customer_id, delivery_notes, delivery_occurrence'` (492) e monta `restMap` só com `{name, chave_pix}` por restaurante (501-505). `confirmarEntrega` (550-623) grava `orders.status='delivered'` + `orders.entrega_pagamento` (JSONB `{metodo, dinheiro?, pix?}`) — **não seta nenhum campo de "pago"**. `uploadComprovante` (~888-891) grava `orders.comprovante_pix_url` (bucket público `comprovantes-pix`).
- **`orders` — colunas relevantes**: `payment_method`, `comprovante_pix_url`, `entrega_pagamento` JSONB, `pago_em` (existe, mas **hoje só é setado pelo módulo Salão/comanda** — nunca pelo fluxo de delivery, nem pelo webhook PagBank em `pagamentos.service.ts` que só grava `pago_em` na própria linha de `pagamentos`, nem por `confirmarEntrega`). Não existe `payment_status`.
- **Caixa/relatório**: `restaurante.service.ts` monta `fluxo_caixa` (linha ~2080-2093) — pra pedidos de delivery (branch `else`, linha 2092) hoje grava `taxa_cartao_valor: 0` **hardcoded**, porque delivery nunca teve taxa de cartão até agora. Isso precisa ler de `orders.entrega_pagamento?.taxa_cartao_valor` quando existir. `confirmarEntrega` já registra entradas de caixa por `meio: 'dinheiro'`/`'pix'` (motoboy.service.ts 586-601) quando `entregaPagamento` tem esses valores — precisa de um terceiro branch `meio: 'cartao'`.

## Decisões de design (assumidas, não re-perguntar)

1. **Novo campo `restaurants.pagamento_manual BOOLEAN DEFAULT false`** — coluna própria, **fora** do JSONB `payment_config` (que é intencionalmente nunca exposto em claro), porque o checkout do cliente (não autenticado como dono) precisa lê-la publicamente.
2. **"Pago" unificado via `orders.pago_em`** (reaproveita coluna existente, sem colisão real com o uso do Salão porque toda query relevante já filtra por `canal`/`status` de delivery) — setado em 3 pontos: webhook PagBank (`pagamentos.service.ts`, quando confirma pago), `confirmarEntrega` do motoboy (quando `entregaPagamento` é informado), e a nova ação "marcar como pago" do dono. `EntregaBarcode.jsx` pula a etapa `pagamento` (vai direto pra `acao`) quando `pedido.pago_em` já vier preenchido.
3. **Rename `orders.comprovante_pix_url` → `orders.comprovante_pagamento_url`** (serve pix e cartão agora) — bucket de storage (`comprovantes-pix`) e rota (`POST /motoboy/pedidos/:id/comprovante`) já são genéricos, não precisam mudar. Só a coluna e o nome da função no frontend (`uploadComprovantePix` → `uploadComprovantePagamento`) e o único uso em `PedidoDetalhe.jsx:373-382`.
4. **Cartão na entrega reaproveita `SalaoService.calcularTaxaCartao`** (mesma fórmula/config do Salão) — motoboy vê total + taxa antes de fechar, gera entrada de caixa com `meio:'cartao'` e alimenta `taxa_cartao_valor` no relatório (mesmo padrão do módulo Salão), com foto obrigatória.
5. **Entrega própria (dono sem motoboy)** fica fora do escopo — sem etapa de cobrança nova lá; o dono usa "marcar como pago" pra esses casos.

## Plano de execução

### 0. Migrations (`deliveryhub_white_label/supabase/migrations/`)
```sql
-- 20260823000002_restaurants_pagamento_manual.sql
ALTER TABLE public.restaurants
  ADD COLUMN IF NOT EXISTS pagamento_manual BOOLEAN NOT NULL DEFAULT false;
```
```sql
-- 20260823000003_orders_comprovante_pagamento_rename.sql
ALTER TABLE public.orders RENAME COLUMN comprovante_pix_url TO comprovante_pagamento_url;
```

### 1. Backend — config do dono (espelhar em `serer_delivery` e `server_delivery`)
- `restaurante.service.ts` `getConfig`/`updateConfig` (~845-940): incluir `pagamento_manual` no `.select()` e no update (campo top-level, fora de `payment_config`).
- `restaurante-config/index.jsx`: novo switch "Receber pagamento manualmente" perto do bloco de Status, com texto explicando o efeito (cliente só informa a forma de pagamento no checkout; motoboy cobra na entrega).

### 2. Backend — expor a flag publicamente pro checkout
- `catalogo.controller.ts`, linhas 295 e 313: adicionar `pagamento_manual` ao `.select(...)`.
- `restaurante-catalogo/index.jsx` `irParaCheckout` (~303-312): incluir `pagamentoManual = !!data?.restaurante?.pagamento_manual` no payload de `pending_cart`/`location.state`, junto de `freteMotoboy`.

### 3. Frontend — checkout pula a tela de pagamento online em modo manual
- `shopping-cart-checkout/index.jsx`: destructure `pagamentoManual` em `SingleCartCheckout` (~389). Em `handleFinalizar` (~450-471), só entrar no bloco de `/pagamentos/pix` se `!pagamentoManual`; em modo manual, sempre `navigate('/order-tracking-status', ...)` direto após criar o pedido, independente do `payment_method` escolhido.

### 4. Backend — "marcar como pago" (painel do dono)
- `restaurante.service.ts`: novo `marcarPedidoPago(pedidoId, restaurantId)` — busca pedido (404 se não achar), `BadRequestException` se `status==='canceled'`, no-op idempotente se `pago_em` já setado, senão `UPDATE orders SET pago_em=now()`.
- `restaurante.controller.ts`: `@Patch('pedidos/:id/marcar-pago')`.
- Query que alimenta `restaurante-pedidos/index.jsx` (`pedidos.service.ts` `listar` ou equivalente): incluir `pago_em`, `canal` no select.
- `restauranteService.js` (frontend): `marcarPedidoPago(id)`.
- `restaurante-pedidos/index.jsx`: botão "Marcar como pago" quando `p.canal !== 'presencial' && !p.pago_em && p.status !== 'canceled'`.

### 5. Backend — setar `pago_em` nos pontos de confirmação
- `pagamentos.service.ts` `processarWebhook` (~264-314): ao confirmar `pago`, além do que já atualiza, setar `orders.pago_em`.
- `motoboy.service.ts` `confirmarEntrega` (~563-564): quando `entregaPagamento` vier, incluir `pago_em: new Date().toISOString()` no `updatePayload`.

### 6. Backend — cartão na entrega (nova etapa, taxa, comprovante)
- `motoboy.service.ts`:
  - `meusPedidos` (492, 501-505): incluir `taxa_cartao_percentual` no select de `restaurants` e no `restMap` (junto de `chave_pix`), e incluir `pago_em` no select de `orders` (492).
  - `confirmarEntrega`: quando `entregaPagamento.metodo === 'cartao'`, calcular `taxa_cartao_valor = await this.salaoService.calcularTaxaCartao(pedido.restaurant_id, pedido.total, 'credit_card')` no backend (não confiar em valor vindo do client), gravar dentro de `entrega_pagamento`. Adicionar branch `meio:'cartao'` no bloco que registra entrada de caixa (586-601), usando `pedido.total + taxa_cartao_valor`.
  - `uploadComprovante` (~888-891): `comprovante_pix_url` → `comprovante_pagamento_url`.
- `restaurante.service.ts` (fluxo_caixa, ~2092): trocar `taxa_cartao_valor: 0` hardcoded por `p.entrega_pagamento?.taxa_cartao_valor ?? 0` (garantir que o select que alimenta esse método já traz `entrega_pagamento` — senão adicionar).

### 7. Frontend — `EntregaBarcode.jsx` + `motoboyService.js`
- `motoboyService.js`: rename `uploadComprovantePix` → `uploadComprovantePagamento`.
- `motoboy-portal/index.jsx` (~589-595): passar novas props `pago={p.pago_em}` e `taxaCartaoPercentual={p.restaurante?.taxa_cartao_percentual ?? 0}` pro `EntregaBarcode`.
- `EntregaBarcode.jsx`:
  - Novo prop `pago` — em `handleScanSuccess` (44) e no fluxo de código manual (157/161), `setEtapa(pago ? 'acao' : 'pagamento')`.
  - Etapa `pagamento` (190-207): novo botão "Cliente vai pagar com cartão (maquininha)", sempre visível (não depende de `chavePix`), abre nova etapa `cartao`.
  - Nova etapa `cartao` (modelada na etapa `pix`, sem QR): mostra total do pedido + taxa calculada (`total * taxaCartaoPercentual/100`) + total a cobrar; captura de foto **obrigatória** (reaproveita `handleFotoChange`/`comprimirImagem` já existentes); botão "Cartão recebido — Marcar Entregue" com `disabled={confirmando || !comprovanteBase64}`, chama `handleEntregar({ metodo: 'cartao', dinheiro: 0 })`.
  - Etapa `pix` (322-328): adicionar `!comprovanteBase64` ao `disabled` do botão (torna a foto obrigatória).
  - Renomear import/uso de `uploadComprovantePix` → `uploadComprovantePagamento`.
- `restaurante-dashboard/PedidoDetalhe.jsx` (373-382): `pedido.comprovante_pix_url` → `pedido.comprovante_pagamento_url`.

### 8. Sincronizar backend com o submódulo
Aplicar todas as mudanças de `serer_delivery/src/{restaurante,motoboy,pagamentos}/` e `salao/` (se tocado) identicamente em `deliveryhub_white_label/server_delivery/src/...` — mesmo padrão já usado no projeto (diff + aplicar, ou copiar direto já que ambos partem do mesmo commit `6ecd30e`).

## Verificação
1. `npx tsc --noEmit` nos dois backends; `npx vite build` no frontend.
2. Ativar "pagamento manual" em Configurações de um restaurante de teste → fazer um pedido delivery escolhendo PIX no checkout → confirmar que **não** abre tela de PagBank, vai direto pro tracking.
3. Como motoboy: pegar esse pedido, escanear, ver que a etapa de pagamento aparece (pedido não pago) → testar as 3 vias:
   - PIX: QR aparece (chave cadastrada), tentar confirmar sem foto (deve bloquear), anexar foto, confirmar.
   - Cartão: nova opção aparece, taxa calculada bate com `taxa_cartao_percentual` configurado, foto obrigatória, confirma.
   - Dinheiro: fluxo igual ao de sempre (sem mudança).
4. No painel do dono, criar outro pedido e clicar "Marcar como pago" antes do motoboy pegar → como motoboy, escanear esse pedido e confirmar que a etapa de pagamento é **pulada** (vai direto pra confirmar entrega).
5. Conferir fechamento de caixa do dia: entrada de dinheiro/pix/cartão da entrega aparecendo corretamente, taxa de cartão da entrega aparecendo no bucket `taxa_cartao` do relatório (não mais hardcoded em 0 pra delivery).
6. Restaurante com "pagamento manual" **desativado** (modo PagBank, comportamento atual): confirmar que nada mudou — PIX ainda abre a tela do PagBank normalmente.
