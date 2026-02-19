---
review_agents:
  - layered-rails
  - rails-reviewer
  - security-sentinel
---

## Review Context

This is Fizzy, a Rails project originally built by 37signals/Basecamp following DHH conventions. We are **gradually adopting layered design principles** from "Layered Design for Ruby on Rails Applications" — clean abstraction boundaries, explicit layers, and specification tests.

### Layered design (primary focus)

The `layered-rails` reviewer has the highest priority. Look for opportunities to:
- Introduce proper abstraction layers (policies, form objects, view components) where they reduce complexity
- Identify layer violations (e.g., controllers reaching deep into model internals, views with business logic)
- Suggest extractions when models or controllers accumulate too many responsibilities
- Encourage specification tests for extracted abstractions

### Rails conventions (secondary)

The codebase still follows many DHH/37signals conventions. Respect existing patterns but don't enforce them dogmatically:
- CRUD controllers with REST resources — keep this
- Expanded conditionals over guard clauses — keep this
- Methods ordered by invocation order — keep this
- Private method indentation under visibility modifier — keep this
- UUID primary keys (UUIDv7, base36-encoded)
- URL path-based multi-tenancy via `Current.account`
- Background jobs that delegate to model methods (`_later` / `_now` pattern)

When DHH conventions conflict with layered design principles (e.g., "no services ever" vs. extracting a well-justified service object), prefer the layered design approach.
