---
name: feedback-monolito-modular-padrao
description: "Standing architecture rule: default to modular monolith for every project; microservices only when explicitly requested"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b86a340f-14e2-4b54-9a62-6008669a8430
  modified: 2026-09-22T11:33:18.428Z
---

Sempre propor/usar **monólito modular** como arquitetura padrão em qualquer projeto novo ou feature grande — um único backend NestJS organizado em módulos por domínio, um único banco de dados por aplicação. Nunca propor microserviços, split de banco, ou serviços distribuídos por iniciativa própria, mesmo diante de requisitos que soem como "escala" ou "desacoplamento" — só considerar essa rota se o usuário pedir explicitamente para aquele projeto específico.

**Why:** confirmado explicitamente pelo usuário em 2026-09-22, depois de mapear a arquitetura do [[project_deliveryhub]] (React+Vite / NestJS modular por domínio / Supabase-Postgres único) e reconhecer esse como o padrão desejado em todo o ecossistema, não uma escolha pontual daquele projeto. Formalizado como [[reference_may_memory_vault|ADR-004-MONOLITO-MODULAR]] no vault (`23-DECISOES/`), que já linkava implicitamente essa direção via ADR-001 ("Back-end: NestJS com API REST e arquitetura modular") mas nunca tinha declarado a restrição de forma explícita.

**How to apply:** ao arquitetar qualquer projeto novo (ou desenhar uma feature grande num projeto existente), default é monólito modular — módulos com fronteira clara (controller/service/DTO próprios) rodando no mesmo processo, mesmo banco. Se o próprio código/projeto já tiver microserviços ou múltiplos bancos por decisão anterior, respeitar o que já existe (não é retroativo), mas não estender esse padrão pra área nova sem confirmação. Se o usuário pedir explicitamente separar em serviços, seguir — mas não sugerir isso a partir de sinais indiretos de "precisa escalar".
