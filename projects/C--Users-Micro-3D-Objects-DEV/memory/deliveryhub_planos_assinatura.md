---
name: deliveryhub-planos-assinatura
description: "Sistema de planos de assinatura da plataforma (mensalidade loja->plataforma) — implementado, falta validar pagamento PagBank real"
metadata: 
  node_type: memory
  type: project
  originSessionId: 82e7a92b-004b-4e31-90e7-2d54f5f7480c
  modified: 2026-08-07T02:03:51.356Z
---

Sistema de planos de assinatura (segundo mecanismo de monetização além da comissão por venda): admin cria planos (nome, valor, periodicidade, limite de produtos, piso de faturamento, trial, módulos Delivery/Salão incluídos), atribui a lojas, loja vê status/paga via Pix PagBank em `/restaurante/plano`, painel bloqueia se fatura vencer além da tolerância.

**Branch**: `feat/planos-assinatura` nos dois repos (deliveryhub_white_label + server_delivery submodule), commitado local, **não mergeado nem pushado**.

**Implementado e testado**:
- CRUD planos, atribuir/trocar/cancelar assinatura por loja (`/admin/planos`)
- Trocar plano recalcula trial/status corretamente e sincroniza `modulo_delivery`/`modulo_salao` da loja com o que o plano inclui
- Limite de produtos bloqueia cadastro
- Geração de fatura (lazy + botão "Renovar agora"/"Gerar fatura" força período aberto, sem duplicar/avançar ciclo em cliques repetidos — bug corrigido)
- Comissão padrão global + override por loja (checkbox "usar padrão")
- Bloqueio de painel do dono por inadimplência

**Pendência pra amanhã**: pagamento Pix real falhou com `PagBank: Invalid credential. Review AUTHORIZATION header` — token sandbox cadastrado em Admin > Configurações > "Conta PagBank Marketplace" está inválido/errado. Precisa gerar/conferir token novo na conta PagBank sandbox (`jotaempresasonline@gmail.com`) e recadastrar. Depois disso, testar fluxo completo: Renovar agora → Pagar → QR Pix → webhook confirma (`/planos/webhook`, precisa de URL pública tipo Cloudflare Tunnel pra confirmação automática funcionar — sem isso dá pra gerar QR mas o "marcar como paga" tem que ser manual pelo admin).

Ver [[deliveryhub_white_label]] pro contexto geral do projeto.
