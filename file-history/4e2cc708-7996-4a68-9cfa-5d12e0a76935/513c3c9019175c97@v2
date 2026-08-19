---
name: feedback-live-artifact-tracking
description: "When a published artifact tracks progress on a multi-step task (e.g. an audit/fix report), keep republishing it to the same URL as work lands, without being asked each time"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4e2cc708-7996-4a68-9cfa-5d12e0a76935
  modified: 2026-08-15T15:37:45.726Z
---

Mid-session during the 2026-08-15 DeliveryHub security audit, after seeing the first published report (findings only, nothing fixed yet), the user said: "sempre atualize [artifact URL] para eu ir acompanhando" (always update it so I can follow along). From that point on, every fix (or batch of fixes) got a republish to the same `file_path` — same URL, updated "Corrigido" badges, updated commit hashes, updated stat cards — without the user having to ask again each time.

**Why:** the user wants one stable link to refresh and see current status, not a play-by-play in chat text — the artifact *is* the status dashboard for a long-running task.
**How to apply:** once a user says this (or the pattern is clearly established — a report/plan artifact tracking an in-progress multi-step task), republish after each meaningful chunk of progress lands, not just at the very end. Keep it to the same `file_path`/URL (never create a new artifact for the same tracked task). Small, low-signal changes don't need their own republish — batch them with the next real update. This generalizes beyond this one report to any artifact explicitly framed as a progress tracker.
