---
name: deliveryhub-cadastro-exige-plano-checkout
description: "Cadastro de restaurante agora exige aderir a um plano (com checkout Pix/Cartão se não tiver trial) antes de liberar o formulário — MERGEADO+PUSHADO+DEPLOY, testado local"
metadata: 
  node_type: memory
  type: project
  originSessionId: 078ad696-7b05-45b5-88a0-d9961bf703d9
  modified: 2026-08-10T20:02:21.018Z
---

Bug reportado: cliente se cadastrava como restaurante e caía direto no painel sem nunca aderir a plano nenhum. Causa: `POST /restaurante/registrar` criava a loja e elevava o role sem nunca criar `assinatura` — e `PlanosService` trata "sem assinatura" como `bloqueado: false` ("loja sem plano = sem limite", de graça pra sempre).

**Fluxo novo (wizard `restaurant-registration-setup`), 2 fases:**
1. **Passo "Escolha seu Plano"** (agora o primeiro da wizard) — pede nome do estabelecimento + plano. Ao confirmar, chama `POST /restaurante/registrar-inicial` (`onboarding.controller.ts`, endpoint novo): cria a loja só com nome, `atribuirAssinatura(plano_id)`, e se o plano **não** tiver trial, força `sincronizarPeriodo(forcar=true)` pra gerar e cobrar a fatura do período atual na hora. Plano com trial pula isso, libera direto.
2. Se `precisa_pagamento`, abre checkout inline (Pix/Cartão) — `PagamentoFaturaModal` (`src/components/restaurante/PagamentoFaturaModal.jsx`, **extraído** do que antes era `PagamentoModal` dentro de `restaurante-plano/index.jsx`, agora compartilhado pelos dois lugares). Só libera Negócio/Contato/Horário/Marca depois de `onPago`.
3. **"Finalizar Cadastro"** virou `POST /restaurante/finalizar` (PATCH-like, `RestaurantOwnerGuard`) — completa endereço/horários/tipo na loja já criada e só AÍ eleva o role pra `restaurant_owner` (antes era feito junto da criação).

**Idempotente**: `registrar-inicial` reconhece loja já existente (reload no meio do checkout) e não duplica.

**Gotchas achados testando (guardar bem):**
1. Trocar de plano DENTRO da wizard (antes de finalizar) e clicar Continuar de novo **ignorava a nova escolha** — só comparava "já tem loja?" sem checar se o `plano_id` mudou. Fix: compara `assinatura.plano_id !== body.plano_id`, reassina se diferente.
2. Fatura pendente do plano anterior ficava presa bloqueando o plano novo (ex: trocar pra um com trial ainda pedia pagamento). Fix: cancela fatura pendente/vencida do plano anterior nessa troca — **restrito a enquanto o role ainda é `customer`** (não virou `restaurant_owner` ainda, ou seja não finalizou o cadastro), pra não abrir brecha de um dono já pagante cancelar dívida real só reenviando outro `plano_id` nesse endpoint.
3. **Bug separado, achado no meio do teste** (não era desta feature, já existia): botão "Renovar agora" em `/restaurante/plano` podia gerar fatura `isenta` (R$0, abaixo do piso de faturamento) duplicada em cliques seguidos — a guarda anti-duplo-clique só olhava status `pendente`/`vencida`, não `isenta`. Fix em `planos.service.ts` `sincronizarPeriodo`: incluído `isenta` na checagem.

PagBank (Pix/Cartão) reaproveita 100% o pipeline já testado em produção (`clientPlataforma()`, token/sandbox vêm de `platform_settings` ou env `PAGBANK_PLATFORM_TOKEN`/`PAGBANK_SANDBOX`) — nenhum código novo de integração, só reuso. Ver [[deliveryhub_planos_assinatura_pagbank]].

**Status**: MERGEADO+PUSHADO em `main` (frontend + backend submodule + standalone sincronizado), testado local pelo usuário nos 3 cenários (plano sem trial pede checkout, planos com trial liberam direto, troca de plano no meio do fluxo). Deploy EasyPanel disparado pelo push, confirmação em produção pendente.
