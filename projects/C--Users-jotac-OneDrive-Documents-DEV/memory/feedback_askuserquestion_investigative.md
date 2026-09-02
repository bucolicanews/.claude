---
name: feedback-askuserquestion-investigative
description: User rejects AskUserQuestion for technical/investigative back-and-forth (where he already knows the answer) and types it directly instead — but engages fine with it for plain approve/pick-a-path decisions
metadata:
  node_type: memory
  type: feedback
  originSessionId: 8d09f23b-e3a5-46d5-805e-025eb4acef26
  modified: 2026-08-27T22:25:06.670Z
---

Twice in one session ([[project-deliveryhub]], GDOOR integration work) the user rejected an `AskUserQuestion` call and answered in plain chat instead:

1. Asked where the GDOOR "serial" field lived (multi-choice) — user rejected, then typed "esta em emitentes o serial" directly.
2. Asked how to package `api_gdoor` for distribution (raw zip vs. build a PyInstaller `.exe`) — user rejected the tool call entirely ("The user doesn't want to proceed with this tool use"), then replied in chat: "ja esta e esta aqui c:\...\api_gdoor.rar" (he'd already made the file himself).

Both were investigative/domain-knowledge questions where the user already had the answer in his head and just wanted to state it, not pick from a menu. By contrast, he answered normally through the structured tool for lower-friction confirm/pick-a-lane questions later the same session (e.g. confirming whether to push pending Supabase migrations to production).

**Why:** for questions that are really "tell me a fact you already know" or "here's what I already did," a multiple-choice UI adds friction over just typing the answer — the user reaches for plain chat instead. Structured options work fine when the choice is genuinely his to make from options Claude is proposing (not recalling/reporting).
**How to apply:** favor a direct plain-text question in the chat over `AskUserQuestion` when the answer is likely a fact only the user has (where something lives, what he already built/decided) rather than a design tradeoff Claude is asking him to weigh in on. Reserve `AskUserQuestion` for cases where Claude is presenting genuine implementation-choice tradeoffs and expects a pick from a small set of forward-looking options — not for extracting known facts or checking what's already been done.
