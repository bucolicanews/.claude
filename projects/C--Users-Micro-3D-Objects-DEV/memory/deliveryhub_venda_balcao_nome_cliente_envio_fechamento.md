---
name: deliveryhub-venda-balcao-nome-cliente-envio-fechamento
description: Venda balcão ganha nome de cliente opcional e só manda itens pra cozinha/bar ao finalizar a venda
metadata: 
  node_type: memory
  type: project
  originSessionId: 3ad9965e-127d-4b5d-aa3a-c07276245050
  modified: 2026-08-09T18:22:29.653Z
---

`/restaurante/salao` → Venda balcão (`VendaBalcaoModal`) tinha 2 comportamentos diferentes do resto do salão que o usuário queria mudar:

1. **Nome do cliente**: campo texto opcional no topo do modal (ícone `User`), salva via `editarClienteComandaSalao` (endpoint `PATCH /comandas/:id/cliente`, já existia — reaproveitado, sem mudança de backend). Aparece automaticamente em Cozinha/Bar/Produção porque esses telas já leem `item.cliente` (`orders.cliente_mesa_nome`) direto do backend, independente de `is_venda_balcao`.

2. **Envio pra cozinha/bar só no fechamento**: antes, `SalaoPdvService.adicionarItens` chamava `enviarItensComoRestaurante` a cada item incluído — igual comanda de mesa normal, cozinha via na hora. Agora esse envio automático só roda se `!comanda.is_venda_balcao`; pra venda balcão, os itens ficam com `status: 'pendente'` (não aparecem nas telas de preparo, que filtram por `status in ('enviado','preparando')`) até `pagar()` finalizar a venda — aí sim `enviarItensComoRestaurante` roda uma vez, mandando tudo junto.

**Why:** usuário quer que o cliente monte o carrinho no balcão sem já disparar preparo cedo demais (evita cozinha começar itens que podem ainda mudar antes do pagamento fechar).

**How to apply:** mesa/comanda normal (garçom) continua enviando item por item na hora, sem mudança — a lógica é isolada pelo flag `is_venda_balcao` em `SalaoPdvService` (`adicionarItens` e `pagar`, `server_delivery/src/salao/salao-pdv.service.ts`).

**Gotcha (2026-08-09, mesmo dia):** efeito colateral direto — como venda balcão só envia os itens pra cozinha/bar DEPOIS de paga, quando o item chega em `/restaurante/producao` a comanda já está com `status: 'paga'`. O guard de `editarItem` (mesmo arquivo) bloqueava qualquer edição de comanda fora de `aberta`/`fechada_garcom`, travando até edição de observação no setor de preparo. Fix: `editarItem` agora libera edição pra comanda `paga` SE `is_venda_balcao` (só observação — quantidade continua bloqueada nesse caso, já foi cobrada). Fica registrado aqui como lição: qualquer novo fluxo onde o pedido chega no setor de preparo DEPOIS de pago precisa revisar todo guard de status que assume "comanda em preparo = ainda aberta".

Status: MERGEADO EM MAIN + PUSHADO (2026-08-09), ambos repos, testado pelo usuário (incluindo o fix da observação).
