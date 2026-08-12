---
name: deliveryhub-export-json-produtos
description: "botão \"Baixar JSON\" na tela /restaurante/relatorios/produtos exporta lista completa de produtos"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3635220f-10a4-4820-82df-b97301ba9607
  modified: 2026-07-25T20:16:15.933Z
---

Adicionado botão "Baixar JSON" em `src/pages/restaurante-relatorios/Produtos.jsx` (função `exportarJson`) e prop `onExportarJson`/`podeExportar` em `FiltroPeriodo.jsx`. Gera arquivo `produtos_<slug-restaurante>_<data>.json` com id, nome, categoria, preço, preco_custo, quantidade_estoque, quantidade_minima, ativo — a partir de `dados.produtos` (já vem do endpoint `getRelatorioProdutos`).

**Status:** testado pelo usuário, mergeado em `main` e pushado pro GitHub (commit `e764b1e`, 2026-07-25). Push de `main` só aconteceu após o usuário confirmar explicitamente a frase "sobe pra produção" e depois "pode, push pra main" — ver [[feedback-trigger-suba-para-deploy]].

**Why:** usuário queria baixar dados de produtos/valores/estoque pra uso externo (planilha, backup, etc).

**How to apply:** essa tarefa era só frontend (`deliveryhub_white_label`), sem mudança em `server_delivery` — não precisou sincronizar os clones do backend (ver [[deliveryhub-dois-clones-server-delivery]]). Push de `main` no GitHub não confirma deploy real no EasyPanel — depende de auto-deploy/webhook configurado lá; não foi verificado se disparou build na VPS.
