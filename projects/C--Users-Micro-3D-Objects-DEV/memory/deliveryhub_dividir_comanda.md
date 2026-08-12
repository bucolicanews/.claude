---
name: deliveryhub-dividir-comanda
description: "Feature \"Separar comanda\" - seleciona itens de uma comanda e cria comanda avulsa nova so com eles"
metadata: 
  node_type: memory
  type: project
  originSessionId: ce53651c-2bd0-46ad-9cf7-505577dd6605
  modified: 2026-07-26T21:28:08.863Z
---

Em 2026-07-26, implementada e mergeada em main (dono/caixa em `/restaurante/salao` e garçom no portal) a feature de dividir comanda: cliente da mesa quer pagar só o que ele consumiu.

**Como funciona:** botão "Separar comanda" abre modal com checkbox por item + campo nome do cliente (obrigatório) e telefone (opcional) da nova comanda. Confirma e:
- Backend cria uma comanda avulsa nova (`orders` insert: `canal: 'presencial'`, sem `mesa_id`, mesmo `garcom_id` da origem, `cliente_mesa_nome`/`cliente_mesa_telefone` do que foi digitado).
- Move os `order_items` selecionados (`UPDATE order_items SET order_id = novaComanda.id`) — não exige item "pendente", funciona mesmo com item já enviado/preparando/pronto (só muda quem paga, não mexe no workflow de cozinha).
- Recalcula `total` das duas comandas (origem e nova).
- Só funciona com comanda `status = 'aberta'` e exige deixar pelo menos 1 item na origem (pra mover tudo já existe `transferir`).

Endpoints: `POST /restaurante/salao/comandas/:id/dividir` (dono, `SalaoPdvService`) e `POST /garcom/comandas/:id/dividir` (garçom, `SalaoService` — service **separado** do dono, ver [[deliveryhub_dois_clones_server_delivery]] pra outro tipo de duplicação nesse projeto).

**Editar cliente pelo dono:** nessa mesma leva, adicionado `PATCH /restaurante/salao/comandas/:id/cliente` — o dono/caixa não tinha como corrigir nome/telefone do cliente numa comanda (só o garçom tinha isso, via `EditarClienteModal` no portal). Agora tem lápis igual no `ComandaModal`.

**Select de transferir lista comandas avulsas:** o select "Transferir mesa/comanda pra..." só mostrava mesas — o backend `transferir()` já suportava `comanda_destino_id` (juntar com outra comanda direto) mas o frontend nunca oferecia essa opção. Corrigido: select agora tem `<optgroup>` Mesas + Comandas avulsas, value codificado como `mesa:<id>` ou `comanda:<id>`.

**Why:** pedido direto do usuário — situação real de mesa com clientes que querem dividir a conta.

Ver [[project_deliveryhub_white_label]].
