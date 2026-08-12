---
name: deliveryhub-ajuste-manual-caixa-23-16reais
description: "Ajuste manual pontual na Cloud: caixa id=23 ganhou entrada de R$16 faltante (bug de valor_recebido null, pagamento anterior ao deploy do fix)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 31cc1ec5-40ca-45dd-ab92-f454ec7203d9
  modified: 2026-07-31T00:32:38.631Z
---

2026-07-30, restaurante "Sereia do Mar" (slug `restor`, restaurant_id=1): comanda #5 (order id 197), pagamento id 227, R$16 em dinheiro, `valor_recebido` NULL — registrado ANTES do deploy do fix de [[deliveryhub_fix_caixa_estorno_permissoes]] (Bug 2: pagamento exato sem troco não creditava o caixa). `caixas.entradas` do caixa aberto (id=23) estava vazio, "Espécie no caixa" mostrava só o fundo inicial (R$13) sem somar essa venda.

**Ação tomada (SELECT de investigação + 1 UPDATE direto na Cloud, autorizado explicitamente pelo usuário nesta conversa):**
```sql
update caixas set entradas = entradas || '[{"descricao": "Venda em dinheiro - Comanda #5 (ajuste manual)", "valor": 16, "meio": "dinheiro", "tipo": "venda_dinheiro", "criado_em": "2026-07-30T21:09:42.304Z"}]'::jsonb where id = 23;
```

**Why:** o fix já deployado só previne o bug em pagamentos NOVOS — não corrige retroativamente caixas/pagamentos já lançados antes do deploy. Esse tipo de ajuste manual é caso a caso, não automático.

**How to apply:** ver [[feedback_banco_local_nunca_mudar_cloud]] — isso foi uma exceção pontual com autorização explícita e específica do usuário (mostrou os dados, pediu o ajuste, expliquei o que ia rodar antes). Não é permissão permanente pra mexer na Cloud — cada caso futuro precisa de novo pedido explícito. Se aparecer outro caixa "sem somar dinheiro" de ANTES de 2026-07-30, mesma causa provável (valor_recebido null); dá pra achar via `select * from comanda_pagamentos where forma_pagamento='cash' and valor_recebido is null`.
