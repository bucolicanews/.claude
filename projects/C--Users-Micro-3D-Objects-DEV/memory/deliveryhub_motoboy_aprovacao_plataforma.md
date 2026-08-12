---
name: deliveryhub-motoboy-aprovacao-plataforma
description: Motoboy só vê/solicita vaga em estabelecimentos após admin aprovar cadastro na plataforma; recusado pode pedir revisão limitada e configurável — MERGEADO+PUSHADO+DEPLOY+MIGRATION CLOUD
metadata: 
  node_type: memory
  type: project
  originSessionId: 078ad696-7b05-45b5-88a0-d9961bf703d9
  modified: 2026-08-10T20:49:19.569Z
---

Antes: motoboy se cadastrava e já podia ver/solicitar vaga em qualquer restaurante — só existia aprovação por restaurante individual (dono aceita/recusa), nenhuma aprovação de plataforma.

**Implementado:**
- `motoboys.status_plataforma` (pendente/aprovado/recusado, default pendente) + `motivo_recusa_plataforma` + `revisoes_solicitadas`. Motoboys que já existiam antes da migration foram **auto-aprovados** (backfill no próprio migration) — só cadastro novo cai pendente.
- `GET /motoboy/me` retorna status + `limite_revisoes_plataforma`. `buscarEstabelecimentos`/`solicitarAfiliacao` (`MotoboyEstabelecimentosController`) bloqueados (403) até `status_plataforma === 'aprovado'`.
- Admin novo: `/admin/motoboys` (lista por status, documentos via signed URL do bucket privado `motoboy-documentos`, aprovar, recusar com motivo).
- **Pedido de revisão**: motoboy recusado tem botão "Solicitar revisão" no portal (`POST /motoboy/solicitar-revisao`) — reabre como `pendente`. Limitado a N tentativas (`platform_settings.config.motoboy_limite_revisoes`, default 2), configurável em `/admin/configuracoes` → bloco "Comissão e Inadimplência" (reaproveitado o form/handler existente, só mais um campo). Admin vê quantas revisões o motoboy já usou no modal de detalhe.

**Status**: MERGEADO+PUSHADO em `main` (frontend + backend submodule + standalone sincronizado) + **migration aplicada na Supabase Cloud** via `supabase db push --linked` + deploy EasyPanel disparado pelo push. Testado local pelo usuário antes do deploy.

Ver [[deliveryhub_agente_impressao_local]] pro padrão geral de aprovação/documento, [[feedback_migration_precisa_push_cloud_apos_deploy]] — dessa vez já foi feito na hora, não ficou pendente.
