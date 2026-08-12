---
name: feedback-migration-editada-nao-reaplica
description: Editar SQL de uma migration já criada não atualiza o banco local sozinho — precisa reaplicar manualmente
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c012bc3f-a116-4487-bf28-de60d1ae9025
  modified: 2026-07-28T02:43:07.260Z
---

Se um arquivo de migration em `supabase/migrations/` já foi rodado uma vez no Postgres local (mesmo que a linha ainda não tenha sido commitada no git) e depois eu edito esse mesmo arquivo pra adicionar colunas/tabelas, o banco local NÃO se atualiza sozinho — só o arquivo `.sql` muda, o schema real do Postgres continua com a versão antiga.

**Why:** causou bug real no fluxo de repasse garçom ([[deliveryhub_plano_motoboy_multi_estabelecimento]] não, ver contexto: feature de repasse gorjeta/comissão) — adicionei colunas `valor_dinheiro`, `valor_pix`, `caixa_id`, `saida_criado_em` na migration `20260727190000_garcom_repasses.sql` depois que a tabela já tinha sido criada localmente com a versão anterior (só `valor_gorjeta`/`valor_comissao`). Backend passou no `tsc --noEmit` (TypeScript não vê o banco), mas em runtime o Supabase/PostgREST retornava erro de coluna inexistente. Pior: o código só desestruturava `data` do resultado do Supabase sem checar `error`, e um `if (!repasse) throw NotFoundException('Repasse não encontrado')` mascarou o erro real de schema como se fosse "registro não encontrado" — mensagem enganosa que não apontava pra causa raiz.

**How to apply:** sempre que eu editar um arquivo de migration que JÁ pode ter rodado localmente (não só no momento de criar ele pela primeira vez), depois de terminar o código rodar `docker exec supabase_db_<projeto> psql -U postgres -d postgres -c "\d <tabela>"` (ou consulta em `information_schema.columns`) pra comparar contra o que o arquivo `.sql` espera, antes de considerar a tarefa testável pelo usuário. Se destoar, aplicar o `ALTER TABLE ... ADD COLUMN IF NOT EXISTS ...` direto no banco local (não destrutivo, seguro — é local, ver [[feedback_banco_local_nunca_mudar_cloud]]) em vez de pedir pro usuário rodar `supabase db reset` (que apaga dados de teste). Também: nunca deixar uma query Supabase descartar silenciosamente o campo `error` — sempre checar/logar antes de tratar `data` nulo como "não encontrado".
