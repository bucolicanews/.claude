---
name: feedback_banco_local_nunca_mudar_cloud
description: "Sempre usar Supabase local pra desenvolvimento/testes; Supabase Cloud (produção) só pra consulta, nunca alterar/escrever"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d4d5a3c9-4437-4241-83cd-b23d777d16a9
  modified: 2026-07-27T22:38:20.334Z
---

Regra: todo desenvolvimento, teste e migration roda contra Supabase **local** (`supabase start`, portas 5433x — ver [[deliveryhub_supabase_local_setup]]). Supabase Cloud (projeto `delivery_jota`, linked) só pode ser **consultado** (SELECT via `supabase db query --linked`), nunca escrito/alterado diretamente — nem UPDATE, nem push de migration solta, nem edição manual de dado.

Why: banco de produção real com dados de clientes/vendas ativos — mudança direta sem passar por deploy normal (migration versionada + merge main) arrisca quebrar produção ou divergir do código.

How to apply: se precisar checar algo em produção (ex: conferir se venda bateu, achar registro), pode rodar `supabase db query --linked "select..."`. Pra qualquer escrita (INSERT/UPDATE/DELETE, mudança de schema), só via migration commitada + merge/push normal do fluxo (ver [[feedback_sempre_local_sem_permissao_web]], [[feedback_trigger_suba_para_deploy]]) — nunca `db query --linked` com INSERT/UPDATE nem edição manual no Studio Cloud.
