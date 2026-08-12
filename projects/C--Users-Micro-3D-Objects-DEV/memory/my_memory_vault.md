---
name: my-memory-vault
description: "Vault Obsidian em C:\\Users\\Micro\\3D Objects\\DEV\\my_memory com politicas, ADRs e diretrizes do ecossistema JHON"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 3eaea5f7-78bd-486d-86dd-4fe0868eb5c2
---

Vault Obsidian (repo git próprio) em `C:\Users\Micro\3D Objects\DEV\my_memory`. Índice raiz: `INDEX.md`. Estrutura por pastas numeradas (00-INBOX, 05-WORKFLOWS, 07-PROJETOS, 13-LOGS, 18-MEMORIA, 19-INFRAESTRUTURA, 20-OBSERVABILIDADE, 21-SEGURANCA, 22-ENGENHARIA, 23-DECISOES, 24-INCIDENTES, 25-SKILLS_PLUGINS, 26-DESIGNER, 27-JARVIS).

Docs chave já lidos:
- `21-SEGURANCA/POLITICAS.md` → [[security_policy_jhon]]
- `22-ENGENHARIA/DIRETRIZES-ENGENHARIA-SOFTWARE.md` → [[engineering_guidelines_jhon]]
- `26-DESIGNER/DESIGN SYSTEM OFICIAL(DELIVERY-RESTAURANTES).md` → [[design_system_delivery]]
- `19-INFRAESTRUTURA/STACK-OFICIAL.md` — stack padrão do ecossistema: Vue3/Nuxt3 + Pinia front, NestJS + Prisma/TypeORM back, Postgres+Redis, Docker. (Nota: projeto deliveryhub usa React, não Vue — stack real do projeto diverge do padrão "oficial" do vault, seguir o que já está implementado.)
- `23-DECISOES/ADR-002-POLITICA-CREDENCIAIS.md` — nunca gravar segredo real no vault, sempre `[MASKED]`.

**Why:** vault é fonte de verdade de políticas/decisões do usuário (identidade "Ecossistema JHON") — consultar antes de iniciar/continuar qualquer projeto, por pedido explícito do usuário.

**How to apply:** antes de propor arquitetura ou mudança relevante em qualquer projeto no diretório DEV, checar pastas 21-SEGURANCA, 22-ENGENHARIA, 23-DECISOES relevantes. Se o projeto tiver pasta própria em 07-PROJETOS, ler primeiro.
