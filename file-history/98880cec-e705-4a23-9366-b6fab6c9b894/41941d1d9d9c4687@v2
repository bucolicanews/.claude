---
name: feedback-browser-testing
description: User prefers to manually test UI features in the browser themselves rather than having Claude drive browser automation
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 98880cec-e705-4a23-9366-b6fab6c9b894
  modified: 2026-08-14T02:39:59.939Z
---

When a feature needs verification in the browser (DeliveryHub or otherwise), don't proactively drive Chrome automation through the login/navigation flow to click-test it. The user interrupted mid-session ("deixe eu testo" — let me test) when Claude started clicking through the restaurant panel login to verify a feature. They then tested it themselves and reported back ("testado, pode pushar").

**Why:** the user wants to be the one exercising the UI personally — likely faster for them than watching automated clicks, and they trust their own manual check more for this kind of feature validation.
**How to apply:** for [[project-deliveryhub]] (and similarly-scoped projects), verify a change is *implemented correctly* via code inspection (read the diff, check the endpoint exists, confirm the built `dist/` is current) rather than clicking through it live. If browser verification seems genuinely useful, ask first instead of just launching into it. Take the user's own "testado" as the signal that it's confirmed working — don't re-verify in the browser after they've said so.
