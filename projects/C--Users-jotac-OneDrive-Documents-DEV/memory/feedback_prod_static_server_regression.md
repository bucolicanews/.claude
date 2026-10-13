---
name: feedback-prod-static-server-regression
description: "Swapping a production static-file server for custom code without checking compression parity caused a real page-load regression in DeliveryHub; user wanted immediate revert, not an in-place fix"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 7f3bbfcf-4ac4-48a0-8f07-f184d38da318
  modified: 2026-09-26T00:49:51.312Z
---

Replacing a production serving component (e.g. the `serve` npm package that served `deliveryhub_white_label`'s built frontend) with custom code needs a header-level parity check — not just "does it functionally work" — before it's considered done. On 2026-09-25, `scripts/serve-prod.cjs` (a plain `node:http` static server, written to inject per-domain `og:image`/`og:title` for White Label stores) was written to replace `"start": "serve -s build"` and shipped to production. It never gzip/brotli-compressed responses, while `serve` did (confirmed via `curl -H "Accept-Encoding: gzip, br"`: old `serve` sent the main JS bundle as `Content-Encoding: br`, the new script sent it raw — 7.9MB instead of ~1.1MB, a ~7-8x payload increase on the largest asset). User reported the site "não carrega" / slow right after deploy; this was the cause, not their internet.

**Why:** a static file server does more than serve bytes — compression, caching headers, conditional requests (ETag/304) are load-bearing production behavior that's easy to forget when hand-rolling a replacement focused on one specific feature (here, dynamic meta tags). The custom script was tested for the feature it was built for (per-domain OG tags — confirmed working) but not diffed against the tool it replaced for baseline serving behavior.

**How to apply:** before swapping any production-facing infra component (static server, proxy, middleware) for custom code, `curl -sD -` both the old and new implementation with `Accept-Encoding: gzip, br` on the *largest* assets and diff `Content-Encoding`/`Content-Length`/`Cache-Control` — not just functional correctness of the new feature. If a user reports something broke or slowed down right after such a deploy, treat the infra swap as the prime suspect first. When the user says "volte como era antes" about a recent infra change, revert immediately via `git revert` (keeps history, safe on already-pushed commits) rather than attempting to patch the new code in place — confirmed 2026-09-25: user wanted the revert pushed right away, not a fixed version of the new server offered as an alternative.

See [[project_deliveryhub]] for the repo/deploy model (push to main = deploy on the tunnel/VPS environment, so this kind of regression goes live immediately on push).
