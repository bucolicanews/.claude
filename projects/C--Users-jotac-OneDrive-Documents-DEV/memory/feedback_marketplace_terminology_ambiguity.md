---
name: feedback-marketplace-terminology-ambiguity
description: "DeliveryHub reuses \"pacote\" and \"carrossel\" across unrelated concepts (planos, marketplace-boost, tags) — confirm which one before implementing"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d036e1b3-bb01-4871-9700-21287a8ce4bf
  modified: 2026-09-10T17:03:23.677Z
---

No DeliveryHub, algumas palavras do domínio têm mais de um significado dependendo do contexto:

- **"Pacote"** pode ser (1) pacote de destaque do marketplace-boost (posição paga num carrossel), ou (2) plano de assinatura (mensalidade). O pedido original "editar os pacotes das empresas" em `/admin/empresas` foi ambíguo entre os dois — só ficou claro depois de uma pergunta direta ([[project_deliveryhub]], seção Marketplace Boost 2026-09-09/10).
- **"Carrossel"** pode ser (1) uma tag de `tags_catalogo` usada pra agrupar produtos organicamente na home, ou (2) o mesmo slug usado como eixo da config paga de vagas/composição do marketplace-boost. O usuário confundiu "vagas pagas por carrossel" (teto global compartilhado por todos os pacotes) com "quantos produtos por carrossel uma empresa pode marcar de graça" (limite orgânico por tag) na mesma sessão, exigindo explicação e depois uma feature nova pra separar os dois conceitos.

**Why:** assumir o significado errado teria produzido uma feature inteira fora do que o usuário queria — cada uma dessas ambiguidades já gerou pelo menos uma rodada de `AskUserQuestion` de esclarecimento nesta sessão antes de codar.
**How to apply:** sempre que o usuário mencionar "pacote" ou "carrossel" num pedido do DeliveryHub, parar e confirmar qual conceito antes de escrever código — especialmente se o pedido fizer sentido plausível dos dois jeitos. Não assumir pelo contexto imediato da tela mencionada (ex: `/admin/empresas` não implica automaticamente "plano", pode ser marketplace-boost).
