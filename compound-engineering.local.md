---
review_agents:
  - rails-reviewer
  - security-sentinel
---

## Review Context

This is Fizzy, a Rails project by 37signals/Basecamp. Follow DHH's Rails style conventions as described in STYLE.md and AGENTS.md.

Key patterns to enforce during reviews:
- Vanilla Rails approach (thin controllers, rich models, no unnecessary services)
- CRUD controllers with REST resources
- Expanded conditionals over guard clauses
- Methods ordered by invocation order
- Private method indentation under visibility modifier
- UUID primary keys (UUIDv7, base36-encoded)
- URL path-based multi-tenancy via `Current.account`
- Background jobs that delegate to model methods (`_later` / `_now` pattern)
