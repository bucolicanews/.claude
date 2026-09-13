# Fase 8 — Ponto Eletrônico (jota_integrador)

## Contexto

Última fase do roadmap original de port jotaCaixa→jota_integrador ainda não iniciada. Escopo confirmado com o usuário: **completo, igual jotaCaixa** — bater ponto (selfie+geo), folha mensal com saldo, falta/abono, folga trabalhada (extra100/compensação), férias integradas ao cálculo, impressão da folha. É o módulo mais complexo do roadmap (mais regra de negócio que qualquer fase anterior).

Pesquisa em duas rodadas: (1) jotaCaixa (`src/pages/PontoEletronico.tsx`, `FolhaPonto.tsx`, `src/components/ponto/*`, `GerenciarFaltas.tsx`, `GerenciarFolgaTrabalhada.tsx`, `GerenciarFerias(Admin).tsx`, `use-ponto-status.ts`) — mapeou toda a regra de negócio. (2) jota_fiscal_frontend — **não existe captura de câmera ao vivo nem geolocalização no projeto ainda**; o único precedente de "selfie" é `AssinarContrato.tsx` (Fase 6), que usa `<input type="file" accept="image/*" capture="user">` como **simplificação deliberada já documentada no código** ("sem captura de câmera ao vivo... cai pra upload normal no desktop") — replico o mesmo padrão aqui, não construo um componente `getUserMedia` do zero. Pra impressão, `DialogImprimirProtocolo.tsx` é o **padrão comprovado em produção** (string HTML inline + `window.open`+`print()`); o hook genérico `usePrint()` existe mas nunca foi usado por ninguém — sigo o padrão comprovado, não o hook órfão.

## Mapeamento pro jota_integrador (3 níveis, sem duplicar schema por tenant)

jotaCaixa tem tabelas paralelas por tenant (`registros_ponto`/`admin_registros_ponto`, `ferias`/`admin_ferias_user`) porque não tem hierarquia de 3 níveis. Aqui viram **uma tabela só** com `contador_id`/`empresa_id` (exatamente um dos dois, mesmo padrão de coerência já usado em `suporte_tickets`). Só **papéis `OPERADOR_CONTADOR`/`OPERADOR_EMPRESA` batem o próprio ponto** (equivalente ao papel `Usuario` do jotaCaixa); `CONTADOR_DONO`/`EMPRESARIO_DONO`/plataforma são sempre gestores (nunca batem ponto), igual ao jotaCaixa.

Jornada (salário, horas mensais, folgas fixas) vira tabela própria `ponto_configuracao_funcionario` (1:1 com `usuarios`), não colunas soltas na tabela de identidade.

## Schema (nova migration)

```sql
create table ponto_configuracao_funcionario (
  usuario_id uuid primary key references usuarios(id),
  salario numeric(12,2),
  horas_mensais numeric(6,2) not null default 220,
  dias_folga_fixos text[] not null default '{}',
  folga_domingo_obrigatoria boolean not null default true,
  data_inicio_contrato date,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table ponto_registros (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references usuarios(id),         -- o funcionário dono do registro
  contador_id uuid references contadores(id),
  empresa_id uuid references empresas(id),
  tipo text not null check (tipo in ('entrada','saida','falta','abono','compensacao','extra100')),
  horario_registro timestamptz not null,
  selfie_storage_ref text,      -- bucket privado, só entrada/saida não-ajustada
  latitude numeric(9,6),
  longitude numeric(9,6),
  ajuste_manual boolean not null default false,  -- substitui os sentinelas string 'Ajuste Manual'/'N/A' do jotaCaixa
  atestado_storage_ref text,
  observacao text,
  criado_por uuid not null references usuarios(id),
  criado_em timestamptz not null default now(),
  constraint ponto_registros_coerencia_vinculo check (
    (contador_id is not null and empresa_id is null) or (contador_id is null and empresa_id is not null)
  )
);

create table ponto_ferias (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references usuarios(id),
  contador_id uuid references contadores(id),
  empresa_id uuid references empresas(id),
  data_inicio date not null,
  data_fim date not null,
  periodo_referencia text,
  status text not null default 'agendada' check (status in ('agendada', 'concluida', 'cancelada')),
  criado_por uuid not null references usuarios(id),
  criado_em timestamptz not null default now()
);
```

Índices em `(usuario_id, horario_registro)`, `contador_id`, `empresa_id` nas duas tabelas de registro/férias. Bucket privados `ponto-selfies` e `ponto-atestados`. Permissões novas (`ponto_eletronico`: visualizar/criar/editar/excluir, vocabulário fixo do banco) concedidas a `OPERADOR_CONTADOR`/`OPERADOR_EMPRESA`.

**RLS** (reusa `pode_acessar_contador`/`auth_empresa_id`/`auth_papel` já existentes, nenhuma função nova):
- SELECT: `usuario_id = auth.uid()` (o próprio funcionário vê os próprios registros) **OU** papel gestor (`CONTADOR_DONO`/`EMPRESARIO_DONO`/plataforma) com posse do `contador_id`/`empresa_id` do registro. Importante: `pode_acessar_empresa()` sozinho vazaria registro de um colega OPERADOR_EMPRESA pro outro (ambos com o mesmo `empresa_id`) — por isso a policy checa `auth_papel()` explicitamente, não só vínculo.
- INSERT: o próprio funcionário só pode inserir `entrada`/`saida` com `ajuste_manual=false` pra si mesmo; qualquer outro tipo (falta/abono/compensação/extra100/ajuste manual) exige papel gestor com posse do escopo.
- DELETE: só papel gestor com posse do escopo (funcionário nunca exclui o próprio registro, igual jotaCaixa).
- `ponto_ferias`: mesma lógica (SELECT: próprio OU gestor; INSERT/DELETE: só gestor).
- `ponto_configuracao_funcionario`: SELECT próprio OU gestor; INSERT/UPDATE só gestor.

## Backend (`jota_integrador`, módulo `src/ponto-eletronico/`)

Clean Architecture nas mesmas 4 camadas de `suporte/`/`protocolos/`.

**Domínio puro** (`dominio/ponto.ts`, testável sem framework): `proximaAcaoBatida(ultimaBatidaDoDia)` (toggle entrada/saída); `calcularResumoMensal(registros, ferias, configuracao)` → `{jornadaMinutos, trabalhadoMinutos, saldoMinutos, extra100Minutos, diasFerias, diasComFaltaInjustificada, diasQuePrecisamGestao}` (mesma regra do jotaCaixa: jornada=horas_mensais×60, saldo=jornada−trabalhado, folga fixa trabalhada sem Extra100/Compensação registrado entra em `diasQuePrecisamGestao`); validação falta total(8h)/parcial (faltas+abono somam 8h); `JORNADA_DIARIA_PADRAO_HORAS=8`.

**Casos de uso**: `RegistrarBatidaUseCase` (valida toggle, upload selfie, grava lat/lng), `ListarRegistrosUseCase`/`ObterResumoMensalUseCase` (filtro usuarioId+mês), `LancarFaltaOuAbonoUseCase` (atestado opcional, split total/parcial), `LancarFolgaTrabalhadaUseCase` (extra100 ou compensação — compensação auto-insere um `abono` futuro de 8h, igual jotaCaixa), `AjustarRegistrosDoDiaUseCase` (gestor substitui as batidas de um dia — delete+insert, `ajuste_manual=true`), `ExcluirRegistroUseCase`, `Criar/Atualizar/ObterConfiguracaoFuncionarioUseCase`, `Criar/Listar/CancelarFeriasUseCase`, `ObterUrlSelfieUseCase`/`ObterUrlAtestadoUseCase` (signed URL sob demanda, padrão `StorageProtocolosService`). **Reusa `ListarUsuariosUseCase` da Fase 7** pra listar a equipe (funcionários) — nenhum endpoint novo de listagem de funcionário precisa ser criado.

**Controller** `ponto-eletronico` (top-level, não aninhado — igual `suporte`, porque um funcionário pode ser de escopo contador ou empresa): `POST /batidas` (multipart selfie, só o próprio), `GET /registros?usuarioId=&mes=`, `GET /resumo?usuarioId=&mes=`, `POST /falta-abono`, `POST /folga-trabalhada`, `PUT /dias/:usuarioId/:data` (ajuste manual), `DELETE /registros/:id`, `GET/PUT /configuracao/:usuarioId`, `GET/POST/DELETE /ferias`, `GET /registros/:id/selfie-url`, `GET /registros/:id/atestado-url`. Resolução de posse espelha `suporte.controller.ts` (`exigirPosse` por `contadorId`/`empresaId` do registro vs. `usuarioAtual`), com checagem adicional de papel gestor vs. próprio funcionário nas rotas que só um dos dois pode chamar.

Auditoria best-effort em toda mutação (`AuditoriaService`), mesmo padrão dos módulos anteriores.

## Frontend (`jota_fiscal_frontend`)

- `src/hooks/useGeolocation.ts` (novo — `navigator.geolocation.getCurrentPosition`, com fallback de input manual de lat/lng se falhar/negar, igual jotaCaixa).
- Selfie via `<input type="file" accept="image/*" capture="user">` (reusa o padrão já estabelecido em `AssinarContrato.tsx`, sem biblioteca nova).
- `src/servicos/pontoEletronico.js`.
- `src/pages/PontoEletronico.tsx` — widget de bater ponto (papéis `OPERADOR_CONTADOR`/`OPERADOR_EMPRESA`): botão Entrada/Saída (label dinâmico via `proximaAcao`), captura selfie+geo antes de confirmar, alerta de 4h sem bater saída, histórico do próprio mês (usa o mesmo endpoint de resumo/registros).
- `src/pages/FolhaPonto.tsx` — gestão (papéis `CONTADOR_DONO`/`EMPRESARIO_DONO`/plataforma): lista a equipe (reusa `listarUsuarios` da Fase 7 filtrado a `OPERADOR_*`), abre a folha mensal de um funcionário.
- `src/components/ponto/DetalheFolhaPonto.tsx` — tabela mensal (linhas coloridas por tipo, igual jotaCaixa) + cards de resumo (jornada/trabalhado/saldo/extras) + ações.
- `src/components/ponto/AjustarRegistrosDialog.tsx`, `GerenciarFaltaAbonoDialog.tsx`, `GerenciarFolgaTrabalhadaDialog.tsx`, `GerenciarFeriasDialog.tsx` — dialogs de gestão, padrão `Dialog`+`react-hook-form` já usado em `AdminPacotes.tsx`/`GerenciarUsuarios.tsx`.
- Impressão: função `gerarHtmlFolhaPonto(dados, orientacao)` + `window.open(...).print()`, mesmo padrão inline de `DialogImprimirProtocolo.tsx` (não reativa o hook `usePrint` órfão).
- Rotas `/ponto-eletronico` e `/folha-ponto`; `MenuLateral.tsx` ganha "Bater Ponto" (papéis `OPERADOR_CONTADOR`/`OPERADOR_EMPRESA`) e "Folha de Ponto" (papéis `CONTADOR_DONO`/`EMPRESARIO_DONO`/plataforma) na seção "Administração" (mesmo padrão `papeis` da Fase 7).

## Ordem de execução

Backend completo (migration→domínio→casos de uso→infra→controller→module) e testado via curl com os 4 logins fixos primeiro; só depois o frontend — mesma ordem das fases anteriores.

## Verificação

- Backend: `nest build` limpo + boot real. Testar via curl: funcionário bate entrada (toggle bloqueia bater entrada de novo sem saída antes), gestor lança falta com atestado, gestor lança folga trabalhada como compensação (confirma abono futuro auto-criado), gestor ajusta um dia manualmente, resumo mensal bate (jornada/saldo), isolamento cross-tenant (empresa2 não vê ponto de funcionário de empresa1; um `OPERADOR_EMPRESA` não vê ponto de outro `OPERADOR_EMPRESA` da mesma empresa).
- Frontend: `tsc --noEmit` + `vite build` limpos. Clique manual do usuário depois (câmera/geolocalização real só dá pra validar no navegador de verdade).
