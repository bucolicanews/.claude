# Corrigir achados Alta da auditoria DeliveryHub (B4, B6, B7, B8)

## Contexto

Continuação da auditoria de pentest/code review rodada nesta sessão (protocolo `PENTEST_CODE_REVIEW_PROTOCOL.md` do vault `may_memory`), publicada em [Auditoria DeliveryHub](https://claude.ai/code/artifact/48ef13e5-36a3-4f5d-9a25-6dedd1ebaf7a). Os 4 achados Crítica (B1, B2, B3, F1) e um Alta bônus (B5) já foram corrigidos e estão em produção (`serer_delivery` 9fe1e06/2444607, `deliveryhub_white_label` ee25fbf/a988e59). Agora entram os 4 achados Alta restantes: B4, B6, B7, B8 — todos em `serer_delivery` (backend), sincronizados depois no submódulo `deliveryhub_white_label/server_delivery` (checkout separado do mesmo remote, mesma rotina já seguida nas correções anteriores).

O usuário pediu update contínuo do artifact publicado conforme cada correção avança — repetir o padrão já usado (selo "Corrigido" + commits, republicar no mesmo `file_path` pra manter a URL).

## B4 — IDOR em `GET /pagamentos/pedido/:id`

**Arquivos:** `src/pagamentos/pagamentos.controller.ts:38-43`, `src/pagamentos/pagamentos.service.ts` (`buscarPorPedido`, linha ~248).

Mesmo padrão já usado em B1 (`pedidos.service.ts`) e B5 (`criarPix`/`criarCartao`, já shipped): `buscarPorPedido` hoje só filtra por `order_id`, sem checar se o pedido pertence a quem chama.

- Controller: adicionar `@Req() req: any` e passar `req.userId`, `req.userRole`.
- Service: reutilizar o `buscarPedido()` privado já existente (retorna `user_id`) pra validar posse antes de consultar `pagamentos` — igual ao que `criarPix`/`criarCartao` já fazem. Lançar `ForbiddenException` se `callerRole !== 'admin' && pedido.user_id !== callerUserId`.

## B6 — Injeção de filtro PostgREST no login/cadastro do motoboy

**Arquivo:** `src/motoboy/motoboy-auth.service.ts` (`login` linha 151, `cadastro` linha 108-117).

`identificador` (endpoint público) e `body.email`/`body.phone` no cadastro são interpolados direto em `.or(`email.eq.${x},phone.eq.${y}`)`sem validação de formato.

- Adicionar constantes de validação no topo do arquivo:
  ```ts
  const EMAIL_RE = /^[^\s,()]+@[^\s,()]+\.[^\s,()]+$/;
  const PHONE_RE = /^\+?[0-9]{8,15}$/;
  ```
- `login()`: no início, `if (!EMAIL_RE.test(identificador) && !PHONE_RE.test(identificador)) throw new UnauthorizedException('Credenciais inválidas');`
- `cadastro()`: validar `body.email`/`body.phone` (quando presentes) contra os mesmos regex antes do `.or()` de duplicidade, lançando `BadRequestException` se inválido.

## B7 — Mass assignment em impressoras (troca de tenant / token)

**Arquivo:** `src/salao/impressoras.service.ts` (`atualizar`, linha 56-66).

`ImpressoraBody` é interface TS (não DTO validado) e `atualizar()` faz `.update(body)` direto — igual ao que `criar()` no mesmo arquivo já evita fazendo montagem campo a campo.

- Reescrever `atualizar()` pra montar um objeto `campos` só com os campos permitidos (`nome`, `setor`, `tipo_conexao`, `endereco`, `ativo`, `nome_sistema`), cada um só incluído `if (body.X !== undefined)`, replicando o padrão já usado em `criar()` no mesmo arquivo — nunca repassar `body` cru pro `.update()`.

## B8 — CORS aberto (`enableCors()` sem origem)

**Decisão confirmada com o usuário:** allowlist dinâmica via banco (não env var estática), porque o White Label tem domínio próprio por loja (`restaurants.custom_domain`) e a lista cresce por tenant.

**Arquivos:**
- `src/common/` hoje só tem funções soltas (`dominio.util.ts`, `geo.util.ts`), sem module Nest. Criar `src/common/common.module.ts` (provider `CorsOriginsService`, exportado) e importar em `AppModule` — segue o mesmo padrão modular já usado por `SupabaseModule`/`RedisModule`.
- Novo: `src/common/cors-origins.service.ts`.
- `src/main.ts` — trocar `app.enableCors()` por `app.enableCors({ origin: ..., credentials: true })` usando `app.get(CorsOriginsService)`.

**Lógica do serviço** (reaproveitando `normalizarDominio` de `src/common/dominio.util.ts`, já usado por `RestaurantOwnerGuard` pro mesmo tipo de comparação de domínio):

```ts
@Injectable()
export class CorsOriginsService {
  private cache: { origens: Set<string>; expiraEm: number } | null = null;
  private readonly TTL_MS = 60_000;

  constructor(private supabase: SupabaseService, private config: ConfigService) {}

  private origensBase(): string[] {
    return (this.config.get<string>('APP_ALLOWED_ORIGINS') ?? '')
      .split(',').map((s) => normalizarDominio(s.trim())).filter(Boolean);
  }

  private async origensDinamicas(): Promise<string[]> {
    const { data } = await this.supabase.client
      .from('restaurants')
      .select('custom_domain')
      .not('custom_domain', 'is', null)
      .is('custom_domain_status', null); // aprovado = sem pendência/recusa (ver empresas.service.ts atenderSolicitacaoDominio)
    return (data ?? []).map((r) => normalizarDominio(r.custom_domain));
  }

  async estaPermitida(origin: string): Promise<boolean> {
    const dominio = normalizarDominio(origin);
    if (this.origensBase().includes(dominio)) return true;

    const agora = Date.now();
    if (!this.cache || agora > this.cache.expiraEm) {
      const dinamicas = await this.origensDinamicas();
      this.cache = { origens: new Set(dinamicas), expiraEm: agora + this.TTL_MS };
    }
    return this.cache.origens.has(dominio);
  }
}
```

`main.ts`:
```ts
const corsService = app.get(CorsOriginsService);
app.enableCors({
  origin: async (origin, callback) => {
    if (!origin) return callback(null, true); // server-to-server, sem browser
    const ok = await corsService.estaPermitida(origin);
    callback(ok ? null : new Error('Origem não autorizada pelo CORS'), ok);
  },
  credentials: true,
});
```

**Pendência que precisa de input do usuário:** `APP_ALLOWED_ORIGINS` no `.env` precisa dos domínios "base" da plataforma (não White Label) — dev (`http://localhost:4028`, IP de LAN atual) e o domínio de produção do frontend (túnel Cloudflare). Vou usar um placeholder record no `.env` local com os valores de dev já conhecidos (`localhost:4028` + IP atual do `.env`) e perguntar/confirmar o domínio de produção antes de fechar — se não houver um domínio de produção fixo ainda (ex. só IP/túnel dinâmico), documentar isso explicitamente em vez de adivinhar.

## Sincronização e verificação

1. Implementar tudo em `serer_delivery` primeiro.
2. `npx tsc --noEmit -p .` — igual ao que já validou os fixes de Crítica.
3. Copiar os arquivos tocados pro submódulo `deliveryhub_white_label/server_delivery`, commitar lá, `git fetch` + `git rebase origin/main` pra deduplicar automaticamente (mesmo padrão que já funcionou nas correções anteriores).
4. Testar CORS manualmente: com o backend local rodando, confirmar que uma origem não listada é rejeitada (`curl -H "Origin: https://evil.example" ...` sem `Access-Control-Allow-Origin` no retorno) e que a origem de dev (`localhost:4028`) continua funcionando.
5. Commits separados por achado (ou agrupados por afinidade, seguindo o padrão de mensagens já usado: `fix: <resumo> — <achado>`).
6. Depois de cada fix (ou ao final do lote), republicar o artifact no mesmo `file_path`, atualizando o banner de status e os selos "Corrigido" de B4/B6/B7/B8, igual ao que já foi feito pros críticos.
