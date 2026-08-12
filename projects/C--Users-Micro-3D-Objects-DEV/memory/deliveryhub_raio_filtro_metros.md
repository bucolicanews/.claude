---
name: deliveryhub-raio-filtro-metros
description: Filtro de raio da home ganhou opções em metros (20m-2km) além dos km existentes — diferencial do deliveryhub é achar fornecedor bem pertinho — MERGEADO+PUSHADO+DEPLOY
metadata: 
  node_type: memory
  type: project
  originSessionId: 078ad696-7b05-45b5-88a0-d9961bf703d9
  modified: 2026-08-10T21:12:19.646Z
---

Pedido do usuário: deliveryhub se destaca por mostrar fornecedores locais **bem próximos**, então o filtro de raio geográfico (`menu-catalog-product-browse`) precisava de granularidade fina — 20m, 50m, 100m, 200m, 500m, 1km, 2km — além dos 5/10/15/25/50km que já existiam.

**Causa raiz que quase travou tudo**: `distancia_km` no backend (`catalogo.controller.ts`) era arredondado com `Math.round(km * 10) / 10` — 1 casa decimal = precisão de **100 metros**. Filtrar por 20m ou 50m era literalmente impossível (tudo abaixo de 50m arredondava pra 0.0). Corrigido pra `* 1000 / 1000` (precisão de metro).

`RAIO_OPCOES` no frontend virou `[0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 15, 25, 50, 0]` (km, 0 = sem limite). Cards de restaurante mostram distância em metros quando < 1km (`fmtDistancia`), não `"0.023 km"`.

**Testado antes de commitar** (sem depender de GPS/permissão do navegador): setei lat/lng fixo num restaurante de teste local via SQL direto, chamei `GET /r?lat=..&lng=..&raio_km=..` com offsets calculados (15m e 100m) — confirmado matemática exata: 15m passa em raio 20m, some em raio 10m; 100m passa em raio 100m, some em raio 50m. Reverti o lat/lng do restaurante de teste depois (`UPDATE ... SET lat=NULL, lng=NULL`).

**Gotcha da sessão**: editei os dois repos direto em `main` por descuido antes de perceber — corrigido na hora (`git stash` → `checkout -b` → `stash pop`) antes de commitar qualquer coisa. Sempre confirmar `git branch --show-current` antes de começar a editar.

**Status**: MERGEADO+PUSHADO em `main` (frontend + backend submodule + standalone sincronizado), sem migration (só lógica). Deploy EasyPanel disparado pelo push.
