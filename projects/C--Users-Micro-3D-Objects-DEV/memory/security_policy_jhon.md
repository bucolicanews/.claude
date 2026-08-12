---
name: security-policy-jhon
description: Política mestre de segurança do ecossistema JHON (vault my_memory) - regras obrigatórias para todo código
metadata: 
  node_type: memory
  type: project
  originSessionId: 3eaea5f7-78bd-486d-86dd-4fe0868eb5c2
---

Política de segurança obrigatória (`my_memory/21-SEGURANCA/POLITICAS.md`, atualizada 2026-06-06), prioridade sobre decisões técnicas locais.

Regras centrais aplicáveis a qualquer projeto (ex: [[project_deliveryhub_white_label]]):
- Security First: nunca implementar depois proteger; nunca desabilitar segurança para testes em produção.
- Zero Trust: validar todo input (body, query, headers, cookies, tokens, uploads, webhooks).
- Least Privilege + RBAC/ABAC: toda rota crítica valida usuário, papel, permissão, tenant.
- Multi-tenant: toda tabela relevante tem `tenant_id`; Supabase exige RLS em todas as tabelas; proibido dado compartilhado entre empresas sem filtro de tenant.
- Frontend: proibido JWT/refresh token/segredos em localStorage/sessionStorage/IndexedDB; usar cookies HttpOnly+Secure+SameSite=Strict; proibido `dangerouslySetInnerHTML` sem aprovação.
- Backend: DTO + class-validator + class-transformer + Helmet + rate limiting; proibido `any` em input de API pública; nunca SQL interpolado (usar query builder/ORM parametrizado).
- Senha: hash Argon2 (preferencial) ou bcrypt; mínimo 12 caracteres com maiúscula/minúscula/número/símbolo; MFA obrigatório para admin/financeiro.
- Uploads: só JPG/PNG/WEBP/PDF, validar MIME + assinatura binária + tamanho + malware.
- Logs: nunca logar senha/token/cartão/chave privada; auditoria imutável com usuário+tenant+ação+IP+timestamp em toda ação crítica.
- Credenciais: nunca em git/docs/logs/DB/frontend — sempre `[MASKED]` em qualquer registro escrito, segredo real só em cofre (Bitwarden/1Password/Doppler/Secret Manager/CI protegido). Ver [[my_memory_vault]] ADR-002.
- IA no ecossistema: nunca expor segredo, nunca gerar credencial real, nunca desabilitar RLS/validação/autenticação.

**Why:** política formal do usuário, criticidade alta, cobre LGPD/OWASP Top 10/ASVS/API Security Top 10 — pedido explícito para sempre lembrar segurança antes de iniciar/continuar qualquer projeto.

**How to apply:** checar esta lista antes de qualquer implementação de auth, upload, query, endpoint novo, ou log em deliveryhub_white_label ou outro projeto no DEV. Recusar/alertar se pedido do usuário violar alguma regra aqui (ex: pedir para logar senha, desabilitar RLS).
