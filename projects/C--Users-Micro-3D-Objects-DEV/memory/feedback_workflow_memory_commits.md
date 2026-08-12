---
name: feedback-workflow-memory-commits
description: "Usuario quer checagem de memoria antes de todo projeto e commit apos toda acao bem sucedida, anotado em memoria"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3eaea5f7-78bd-486d-86dd-4fe0868eb5c2
---

Regra de fluxo de trabalho pedida explicitamente (2026-07-09):
1. Sempre checar `my_memory` (vault) e a memória persistente própria ANTES de iniciar ou continuar qualquer projeto em DEV.
2. Sempre lembrar das políticas de segurança e diretrizes já registradas (ver [[security_policy_jhon]], [[engineering_guidelines_jhon]]) ao trabalhar em qualquer projeto.
3. Gerar commit git para toda ação bem-sucedida (mudança de código concluída e validada) — não deixar trabalho sem commit.
4. Anotar/registrar isso na memória (este arquivo é o registro).

**Why:** usuário quer continuidade entre sessões e histórico rastreável de progresso; commits frequentes = checkpoints seguros.

**How to apply:** no início de cada sessão/tarefa neste diretório, ler MEMORY.md e memórias relevantes antes de agir. Após completar uma mudança funcional e verificada, propor/criar commit (seguindo protocolo git padrão: mostrar diff, mensagem clara, nunca --no-verify). Não commitar automaticamente sem confirmar escopo com usuário quando ambíguo, mas tratar "commit após ação bem-sucedida" como instrução durável já dada.
