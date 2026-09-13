---
name: feedback-jotacaixa-readonly
description: "jotaCaixa (C:\\Users\\jotac\\OneDrive\\Documents\\DEV\\jotaCaixa) é produção real, leitura-only para a IA — nunca commitar/alterar lá, todo trabalho novo vai pro jota_integrador"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: bb4eee8d-4db2-4e08-9971-17944e03f763
  modified: 2026-09-09T21:07:45.172Z
---

**Nunca rodar `git add`/`commit`/`push`, nem editar/escrever nenhum arquivo dentro de `C:\Users\jotac\OneDrive\Documents\DEV\jotaCaixa`.** Ler é permitido e encorajado (código, migrations, `git log`/`blame`) — só a escrita/commit é proibida.

**Why:** jotaCaixa está em produção com dados reais e dinheiro real passando por ele (PagBank/Stripe) agora, confirmado pelo usuário em 2026-09-09. Mesmo com o repo tendo git de verdade (2455 commits, ver [[project_jotacaixa]]), o usuário foi explícito: "esse não vou mexer. não quero commitar nada no jotacaixa, vamos usar o jota integrador frontend para commitar." Não é uma preferência de estilo — é proteção de um sistema em produção fora do escopo desta IA.

**How to apply:** todo trabalho decorrente da análise do jotaCaixa (módulo contábil, conciliação bancária, contratos) é código **novo**, escrito do zero em `jota_integrador` (backend) e `jota_fiscal_frontend`, dentro da arquitetura já estabelecida lá — nunca uma migração/porta/refatoração do jotaCaixa em si. Se for preciso entender uma regra de negócio específica (cálculo de saldo, lógica de conciliação, etc.), consultar o histórico/código do jotaCaixa é a forma certa de fazer isso, desde que nenhum comando de escrita seja executado nele.