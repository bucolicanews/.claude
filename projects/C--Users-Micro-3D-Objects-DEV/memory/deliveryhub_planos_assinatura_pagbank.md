---
name: deliveryhub-planos-assinatura-pagbank
description: "Sistema de planos/assinatura SaaS do deliveryhub — cobrança PagBank Pix+cartão, upgrade exige pagamento"
metadata: 
  node_type: memory
  type: project
  originSessionId: a3d059f5-e5a3-4f97-a884-e047f4bf4636
  modified: 2026-08-07T23:27:23.794Z
---

Sistema de mensalidade SaaS (loja paga a plataforma, separado da comissão por venda) — `server_delivery/src/planos/planos.service.ts` + tabelas `planos`/`assinaturas`/`plano_faturas`. Frontend: `/restaurante/plano` (dono) e `/admin/planos` (admin, abas Planos/Lojas/Faturas/Instalações Locais).

Funciona: geração lazy de fatura por período (`sincronizarPeriodo`), bloqueio de painel por atraso além da tolerância, botão "Renovar agora" (não duplica fatura se já tem pendente — fix aplicado), pagamento via Pix e via cartão débito/crédito (PagBank.js criptografa no navegador, `payment_method.holder` era obrigatório e faltava — fix aplicado e **testado em produção com sucesso**, cartão de teste oficial PagBank `4539620659922097`).

**Troca de plano (upgrade/downgrade) não efetiva na hora** — gera fatura do valor cheio do plano novo (`iniciarTrocaPlano`), só troca quando a fatura confirma paga (Pix webhook ou cartão na hora, via `aplicarTrocaSeNecessario`). Fatura de troca abandonada não conta pro bloqueio nem trava "Renovar agora" (`plano_id_troca IS NULL` nas queries relevantes).

**Why:** decisão do usuário — trocar de plano sem cobrar deixava buraco (dono upgrada de graça, valor novo só aparece na próxima fatura).

**How to apply:** qualquer mudança em `sincronizarPeriodo`/`pagarFatura`/`pagarFaturaCartao` precisa considerar que `plano_faturas` agora tem titular polimórfico (ver [[deliveryhub-licenciamento-instalacoes-locais]]) e pode ter `plano_id_troca` setado — não é só fatura de renovação normal.

Status: MERGEADO + PUSHADO em main (ambos repos) + migrations aplicadas na Supabase Cloud. EasyPanel redeploy pendente de confirmação do usuário na última rodada.
