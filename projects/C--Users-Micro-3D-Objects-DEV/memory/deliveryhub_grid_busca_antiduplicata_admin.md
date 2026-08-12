---
name: deliveryhub-grid-busca-antiduplicata-admin
description: Grid 2 colunas mobile + busca + bloqueio de nome duplicado em Categorias/Tipos/Tags/Planos (admin)
metadata: 
  node_type: memory
  type: project
  originSessionId: 3ad9965e-127d-4b5d-aa3a-c07276245050
  modified: 2026-08-09T16:12:16.571Z
---

Admin (`/admin/categorias`, `/admin/tipos-estabelecimento`, `/admin/tags`, `/admin/planos`) tinha cards em grid que virava 1 coluna no mobile (desperdiçava espaço), sem busca, e sem bloqueio de nome duplicado (ex: "Bebidas" e "bebidas" coexistindo).

**Categorias e Tipos** (layout grid de cards): grid `grid-cols-2` já no mobile (era `grid-cols-1 sm:grid-cols-2`), cards compactos responsivos, botões editar/remover agora sempre visíveis no mobile (antes só apareciam no hover — inacessível em touch). Campo de busca acima do grid, filtra por nome normalizado (sem acento/case via `\p{Diacritic}`).

**Tags e Planos** (layout lista, não grid): badges/descrição/preço não cabem em card 2 colunas, então mantido layout lista — só entrou busca + bloqueio de duplicata, sem mexer no grid.

**Anti-duplicata:** duas camadas. Frontend checa no submit do modal contra a lista já carregada (normalizado, ignorando acento/case) antes de chamar a API. Backend replica a mesma checagem via `ilike` case-insensitive (`garantirNomeGlobalUnico`/`garantirNomeTipoUnico`/`garantirNomeTagUnico`/`garantirNomePlanoUnico` em cada `*.service.ts`), lança `ConflictException` (409) — necessário porque nem toda tabela tinha `UNIQUE` no banco (`planos.nome` não tinha nenhum; `establishment_types.name`/`tags_catalogo.slug` tinham `UNIQUE` mas case-sensitive, não pegava "Bebidas" vs "bebidas").

**Why:** usuário queria evitar duplicidade de cadastro (ex: categoria criada 2x com capitalização diferente) e melhor aproveitamento de tela no celular.

**How to apply:** ao criar nova entidade admin com CRUD similar (nome único + ícone/cor), replicar o padrão: `normalizarNome` no frontend + `garantirNomeXUnico` (ilike + neq no update) no backend.

Status: MERGEADO EM MAIN + PUSHADO (2026-08-09), testado pelo usuário. Ver também [[deliveryhub-admin-header-e-status-dot]] (fix de header mobile feito na mesma leva).
