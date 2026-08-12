---
name: engineering-guidelines-jhon
description: "Diretrizes de engenharia de software do usuario (vault my_memory) - SOLID, Clean Architecture, limites de complexidade"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3eaea5f7-78bd-486d-86dd-4fe0868eb5c2
---

Diretrizes (`my_memory/22-ENGENHARIA/DIRETRIZES-ENGENHARIA-SOFTWARE.md`) — postura "arquiteto sênior" exigida pelo usuário para todo código gerado.

Regras principais:
- Complexidade ciclomática: ideal até 5, aceitável até 10, acima de 15 obrigatoriamente dividir em funções menores. Preferir early return / guard clauses a if aninhado.
- SOLID sempre. Clean Architecture / DDD quando aplicável, separar Domain/Application/Infrastructure/Presentation.
- Backend: regra de negócio nunca em controller/rota/middleware — usar Services/Use Cases. Controller só recebe, valida, chama serviço, retorna resposta.
- Frontend: componente só apresentação; lógica complexa em composables/hooks/services/stores; evitar componente > 300 linhas.
- Permissões: nunca cadeia de if/else por role — usar RBAC / permission matrix / policies.
- Erros: nunca engolir exceção; usar Result Pattern / Custom Exceptions; sempre logar.
- Refatorar proativamente ao ver código duplicado, função gigante, switch gigante, if/else longo.
- Processo de resposta a pedido de dev: analisar requisito, identificar risco arquitetural, identificar risco de complexidade, propor arquitetura antes de implementar, gerar código, explicar decisão, sugerir melhorias futuras. Priorizar qualidade arquitetural sobre velocidade.

**Why:** doc explicitamente escrito para o "sistema contábil SaaS" do usuário mas o próprio doc generaliza para qualquer projeto — usuário trata isso como padrão pessoal de qualidade.

**How to apply:** usar como checklist antes de propor mudança de arquitetura em [[project_deliveryhub_white_label]] ou outro projeto; não pular direto pra código em tarefas grandes sem antes esboçar a abordagem.
