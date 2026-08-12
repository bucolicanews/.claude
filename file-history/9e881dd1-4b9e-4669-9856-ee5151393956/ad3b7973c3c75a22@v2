---
name: deliveryhub-modulos-delivery-salao
description: admin escolhe por empresa se libera modulo Delivery e/ou Salao — MERGEADO EM MAIN + DEPLOYADO (migration ja na Cloud)
metadata: 
  node_type: memory
  type: project
  originSessionId: 9e881dd1-4b9e-4669-9856-ee5151393956
  modified: 2026-07-27T16:26:47.171Z
---

Feature pedida em 2026-07-27: em `/admin/empresas`, cadastro/edicao de empresa ganhou 2 checkbox independentes — "Delivery" e "Salão (mesas/comandas/garçons)". Antes, Delivery era liberado fixo pra todo mundo e Salão dependia só do `type_id` (tipo de estabelecimento = "Restaurante").

**O que mudou:**
- `restaurants.modulo_delivery` / `modulo_salao` (boolean, migration `20260727000001_modulos_delivery_salao.sql`). Backfill preservou comportamento antigo: delivery=true pra todos, salao=true só quem já era tipo Restaurante.
- Backend `empresas.controller/service.ts` aceita os 2 campos no create/update; `restaurante.service.ts` (`minhaEmpresa`) expõe as flags.
- Novo hook `src/hooks/useModulosEmpresa.js` (não mexeu no `useTipoRestaurante` existente, que continua servindo outras telas — impressoras/comissão em `restaurante-produtos`/`restaurante-config`).
- Nav do painel (`restauranteNavLinks.js`): Delivery/Entregas/Motoboys somem sem `modulo_delivery`; Produção/Bar/Salão/Garçons/Impressoras somem sem `modulo_salao`; Cozinha/Combos/Pedidos (compartilhados pelos dois canais) só somem se os DOIS módulos estiverem desligados — ajuste pedido pelo usuário depois do primeiro teste.

**Why:** dono da plataforma quer poder vender só delivery, só salão, ou os dois, por empresa — sem depender do tipo de estabelecimento.

**How to apply:** se a URL de `/restaurante/salao` ou `/restaurante/delivery` for acessada direto (sem passar pela nav), ainda não tem guard de rota real — isso já era uma lacuna antes desta feature, não foi corrigido (fora do escopo pedido, avisado ao usuário).

**Status:** MERGEADO EM MAIN + PUSHADO (frontend, submodule dev, standalone VPS todos no commit `4cf6e40`) + migration aplicada em produção (Supabase Cloud) em 2026-07-27, gatilho "sobe pra deploy" ([[feedback_trigger_suba_para_deploy]], [[feedback_sempre_local_sem_permissao_web]]). EasyPanel deploy real (build+restart) não confirmado — se não subir sozinho via webhook, precisa redeploy manual no painel.
