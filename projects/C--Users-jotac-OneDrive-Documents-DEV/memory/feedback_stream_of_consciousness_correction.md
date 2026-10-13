---
name: feedback-stream-of-consciousness-correction
description: "User narrates economic/business logic in short fragmented messages mid-work, sometimes reversing course multiple times in a row — distinguish correction from confirmation before rewriting code"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 06a5b2aa-ac37-40b3-9a5d-547d4be43cce
  modified: 2026-09-25T01:16:54.339Z
---

While I'm actively implementing a feature with real business/money logic (freight splitting, commissions, pricing), the user sends short, informal, sometimes-typo'd messages narrating his own understanding of the economics as he reviews — often mid-turn, sometimes several in a row before I finish responding to the first one. These messages can be:

1. **A genuine correction** ("isso está errado, na verdade é assim") — requires re-deriving the logic and rewriting.
2. **A confirmation/monologue** — him thinking out loud to double-check his own mental model matches what got built, phrased as a statement, not a question.

Concretely, on the `frete_embutido` (embedded freight for heavy/bulk products) feature (2026-09-24), the user reversed the same design point **three times in one session**:
- v1: "só bookkeeping interno, nunca afeta o total" (never shown/charged)
- v2: "não, isso substitui o frete geral de verdade, afeta o total" (must replace, must change total)
- v3 (final): "não, a base é embutida (não soma), mas o excedente de km é cobrado de verdade (sempre soma)" — a hybrid he'd had in mind all along, phrased as "eu que fiz vc errar, me desculpe" once he re-read the receipt and realized the model wasn't what he'd described.

Each reversal arrived as a plain statement of "how it works", not framed as "please change X" — I had to infer from context (a screenshot of a wrong-looking receipt, or a short clarifying sentence) whether he was reporting a bug in what I built or restating a rule I'd already implemented correctly (e.g. "a entrega ganha 1,20... a empresa recebe 12-1,20" turned out to be *already true* given the existing commission ledger — no code change needed, just confirming it out loud).

**Why:** these are real production money-flow decisions (what the customer is billed, what the platform takes as commission, what the motoboy is owed) — getting the direction wrong costs real revenue, so the user is visibly working through the model himself in real time rather than handing me a finished spec upfront. See [[project_deliveryhub]] (frete embutido section) for the final settled rule.

**How to apply:** when a short user message restates "how X works" during active work on money-flow logic, before touching code: (1) check whether the statement matches what's *already implemented* — if so, just confirm and explain why, don't rewrite; (2) if it contradicts current behavior, treat it as authoritative and re-derive the total/split logic from scratch rather than patching the previous version incrementally, since the user has genuinely changed the model, not just the wording. Don't ask a clarifying multi-choice question for these — he types out the answer himself unprompted (see [[feedback_askuserquestion_investigative]]); reserve AskUserQuestion for true either/or business decisions he hasn't already resolved out loud (e.g. whether platform commission should apply to freight at all — that one *did* warrant asking, since it was a new fork, not a restatement).
