---
name: feedback-criptografia-pii-padrao
description: "Standing security rule: all personal user data (CPF/CNPJ, address, PIX, documents) must be encrypted at rest in every project, by default"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4dbe6920-8d21-41ad-bdda-8fe00a256e52
  modified: 2026-09-30T15:35:57.103Z
---

Todo dado pessoal sensível (CPF/CNPJ, endereço de entrega/residencial de pessoa física, chave PIX, dados de conta bancária, documentos de identificação) precisa ir **criptografado em repouso** no banco — nunca em texto plano — em qualquer projeto do ecossistema, por padrão, não só quando pedido explicitamente pra aquela tabela/campo.

**Why:** confirmado explicitamente pelo usuário em 2026-09-30, depois de implementar criptografia de PII no [[project_deliveryhub]] (CPF/CNPJ de cliente e entregador, endereço de entrega, chave PIX de repasse) — pediu pra "sempre gravar isso, pra todos os dados dos usuários" e formalizar no vault. A regra já existia na política do vault (`POLITICAS.md`, seção LGPD; `ARCHITECTURE_SECURITY_RULES 1.md`, seção 10/11 — AES-256 pra CPF/CNPJ/PIX/Contas Bancárias/Documentos/Tokens/Chaves) mas nunca tinha sido implementada de fato em nenhum projeto até essa sessão. Formalizado como [[reference_may_memory_vault|ADR-005-CRIPTOGRAFIA-PII-EM-REPOUSO]] no vault (`23-DECISOES/`).

**How to apply:** ao desenhar qualquer tabela nova com CPF/CNPJ/PIX/documento/endereço de pessoa física, em qualquer projeto (não só DeliveryHub), já nascer criptografado — não é hardening posterior. Padrão de implementação (referência viva: `serer_delivery/src/common/encryption.service.ts`, replicado idêntico em `deliveryhub_white_label/server_delivery`):
- AES-256-GCM em nível de **aplicação** (não `pgcrypto` no Postgres), IV aleatório por valor.
- Duas chaves independentes (`PII_ENCRYPTION_KEY`/`PII_HASH_KEY`), via env var, nunca no código, nunca a mesma chave pras duas coisas.
- Campo que precisa de busca exata/dedupe (ex. CNPJ duplicado) ganha uma coluna `<campo>_hash` (HMAC-SHA256, determinístico) ao lado — nunca comparar `.eq()`/`UNIQUE` contra a coluna criptografada em si.
- JSONB (ex. endereço): mantém o tipo, envelope `{"v":1,"enc":"..."}` no lugar do conteúdo.
- Escopo por sensibilidade real: dado de negócio público (endereço de estabelecimento usado em busca) fica de fora; lat/lng fica em claro (necessário pra cálculo de distância/roteirização direto no Postgres); email de login/credencial é escopo separado, maior risco, decisão isolada.
- Dado que já existe em produção precisa de **script de backfill idempotente** (tenta decifrar cada linha — se decifrar já está ok, se falhar é texto plano e criptografa).
- Rollout em produção NUNCA pode ser "deploy do código antes do backfill" — código que já espera ciphertext quebra toda leitura de texto plano ainda não migrado. Ordem: migration aditiva → chaves configuradas no ambiente real (nunca reaproveitar chave de dev) → backfill em produção → só então deploy do código → troca de `UNIQUE`/constraint pra `_hash` por último.
- Ao adicionar QUALQUER select novo numa tabela com PII, lembrar de decifrar antes de devolver — `select('*')`/`select()` sem colunas é um ponto cego fácil de esquecer (vira ciphertext aparecendo na tela em vez do dado real).
