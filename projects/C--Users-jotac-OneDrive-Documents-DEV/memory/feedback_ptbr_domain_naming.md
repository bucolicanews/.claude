---
name: feedback-ptbr-domain-naming
description: "User wants all domain naming (folders, modules, entities, DB fields, business identifiers) in Portuguese, not just prose/commits — generic tech jargon (hook, service, DTO, tenant) stays English"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: a711af78-b29f-4b55-92ce-d724ed2491ae
  modified: 2026-09-06T14:14:28.427Z
---

While setting up `jota_integrador` (see [[project_jota_integrador]]), the user interrupted mid-task: "importante manter toda a nomenclatura em pt-br" — after I'd scaffolded folders/entities with English business names (`pages/fiscal`, `Accountant`, `Company`, `company_id`, `FiscalDocuments`, etc.).

**Rule:** any name describing a *business/domain* concept — folder names for feature areas, entity/class names, DB table/column names, permission strings, constant identifiers — must be in Portuguese. Generic programming jargon with no natural Portuguese equivalent in common use (hook, service, DTO, controller, guard, store, tenant/multi-tenant) stays in English, matching what even the vault's own `may_memory/22-ENGENHARIA/DIRETRIZES-ENGENHARIA-SOFTWARE.md` does.

**Why:** goes beyond [[user_profile]]'s existing note about Portuguese prose/commit messages — this is about code-level naming, which I had defaulted to English for (common industry practice) until corrected. The user cares about domain vocabulary specifically, not blanket translation of every token.

**How to apply:** on any new project/module for this user, name folders and business entities in Portuguese from the start (e.g. `contadores`, `empresas`, `documentos-fiscais`, `RegistroDeCreditos`, `empresa_id`/`contador_id` not `company_id`/`accountant_id`). When unsure whether a term is "generic tech jargon" vs "domain concept," lean toward translating — ask only if genuinely ambiguous. Applied concretely in `jota_integrador_backend`/`jota_integrador_frontend` docs (2026-09-06): renamed `company_id`→`empresa_id`, `accountant_id`→`contador_id`, `Company`→`Empresa`, `Accountant`→`Contador`, `DOWNLOAD_XML`→`BAIXAR_XML`, kept `Presentation/Application/Domain/Infrastructure` (Clean Architecture layers) and `tenant` in English as established jargon.
