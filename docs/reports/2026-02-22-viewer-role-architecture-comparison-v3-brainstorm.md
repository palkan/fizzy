# Architecture Comparison: Viewer Role Implementation (v3)

**Date:** 2026-02-22
**Status:** Analysis Complete
**Previous versions:** v1 (`2026-02-21-...brainstorm.md`), v2 (`2026-02-21-...v2-brainstorm.md`)

---

## Executive Summary (2 slides)

### Slide 1: The Experiment

Two AI agents implemented the same 3-step feature on the same codebase with different architectures:

| | **Base** (vanilla Rails) | **Layers** (Action Policy) |
|---|---|---|
| **Starting point** | Ad-hoc `before_action` guards, model predicates | Policy objects, `authorize!` + `authorized_scope` in controllers |
| **Feature** | Viewer role + per-column access + role-tiered column restrictions |
| **Files changed** | 91 | 57 |
| **Controllers touched** | 35 | 8 |
| **Security bugs** | Card movement target unfiltered | `CardPolicy#manage?` missing column check |
| **Secondary data paths** | All covered (via `User::Accessor`) | All covered (via policy scopes + concerns) |

### Slide 2: The Takeaway

**Where layered architecture wins**: Role-based authorization rules (C1). Adding a new role touched 6 policy files vs. 28 controller guards. Review effort ~40-50% lower. Fewer files = fewer places to miss.

**Where vanilla Rails holds its own**: Data-path filtering (C2). The `User::Accessor` override pattern provides implicit coverage across all consumers with a single override point.

**The real insight**: Architecture choice has the strongest impact on **rule-based changes** (who can do what). It matters less for **data-path changes** (what can be seen where). Both AIs missed something different -- neither architecture prevents bugs, but the layered version makes them easier to find and fix (one policy file vs. 27 controllers).

---

## Methodology

The layers branch's base (`vova-layers`) had an automatic, unaudited Action Policy migration. In practice, a human reviewer would ensure this migration is complete before building features on top. **v3 assumes a properly completed migration**, meaning:

1. Every controller action has appropriate `authorize!` calls
2. Collection endpoints use `authorized_scope` (which applies `relation_scope` from policies)
3. `set_*` methods use explicit rules (`authorize! @card, to: :show?`)

Changes that merely add missing `authorize!` calls, replace `skip_authorization` placeholders, or add `authorized_scope`/`accessible_by` filtering that the policy framework should already provide are excluded as **migration gaps** (9 files: 7 controllers, 2 views). See [Appendix: Migration-Gap Files](#appendix-migration-gap-files) for the full list.

---

## What We're Comparing

Two implementations of the same three-step feature built on different architectural foundations:

- **Base branch** (`viewer/base/compound-v3` from `vova-main`): Classic 37signals/DHH Rails -- ad-hoc `before_action` guards, model predicates, `User::Accessor` overrides. No authorization framework.
- **Layers branch** (`viewer/layers/compound-v3` from `vova-layers`): Layered architecture with Action Policy -- policy objects, `authorize!` calls, `allowed_to?` in views, `authorized_scope` for collections.

Feature requirements evolved identically across three commits:

1. **Viewer role** -- read-only users who can view boards/cards, comment only on triage cards
2. **Per-column viewer access** -- board admins can hide columns from viewers
3. **min_role for columns** -- generalize to role-tiered column access (viewer < member < admin)

---

## Statistical Overview

### Change Matrix (files changed / insertions / deletions)

|                | Base branch         | Layers branch       |
|----------------|---------------------|---------------------|
| Commit 1       | 62 / +1,242 / -115  | 36 / +1,123 / -87   |
| Commit 2       | 27 / +695 / -18     | 23 / +675 / -18     |
| Commit 3       | 23 / +751 / -122    | 29 / +763 / -105    |
| **Net total**  | **91 / +2,569 / -136** | **67 / +2,464 / -113** |

### Files by Category (net total)

| Category    | Base | Layers |
|-------------|------|--------|
| Models      | 7    | 9      |
| Controllers | 35   | 8      |
| Views       | 23   | 13     |
| Policies    | 0    | 7      |
| Helpers     | 2    | 1      |
| Tests       | 10   | 15     |
| Fixtures    | 4    | 4      |
| Migrations  | 2    | 2      |
| **Total**   | **83** | **59** |

### Cross-Commit Churn (files modified in 2+ commits)

| Commit pair | Base | Layers |
|-------------|------|--------|
| C1 & C2     | 1    | 3      |
| C2 & C3     | 17   | 19     |
| C1 & C3     | 3    | 4      |

Both branches show significant C2->C3 churn (~17-19 files), which is expected: the boolean approach from C2 was generalized to `min_role` in C3.

---

## Architecture Analysis

### Commit 1: Viewer Role

**Base approach**: Created `ensure_contributor` guard in `Authorization` concern, applied via `before_action` to **27 controllers** individually. Added `contributor?` predicate to `User::Role`, `contributor?` helper for views, `commentable_by?` to `Card::Commentable`, and `cleanup_on_viewer_demotion` callback.

**Layers approach**: Added `not_viewer?` check to `ApplicationPolicy`, then overrode `create?`/`manage?` in 6 policy files. 3 controllers needed feature-specific changes (settings tightening, reaction policy delegation, role selector update). Views use `allowed_to?` instead of a new helper.

**Key difference**: The base version touches **31 controllers** vs **3** in layers. Without a policy framework, every controller endpoint needs an explicit guard. With policies, rules propagate automatically through existing `authorize!` calls and `authorized_scope`.

### Commit 2: Per-Column Viewer Access

Both branches add a boolean column (`hidden_from_viewers` / `viewer_restricted`) and filter at multiple data paths.

**Base approach**: Adds `visible_to(user)` scopes to Column and Card models, overrides `accessible_columns`/`accessible_cards` in `User::Accessor`. The Accessor overrides provide **implicit coverage** of all data paths that use `user.accessible_cards` (Filter, Search direct lookup, Autocomplete, DataExport). Additionally, `Search::Record` and `DayTimeline` have their own independent filtering.

**Layers approach**: Adds checks in policies (`CardPolicy#show?`, `ColumnPolicy#show?`, `CardPolicy#relation_scope`) and filters in data path models (Filter, Search::Record, DataExport). Collection endpoints that use `authorized_scope` get filtering automatically via `relation_scope`. 3 controllers need changes: `boards/columns_controller` (params), public boards (no AP), and searches (independent path).

**Key difference**: The base branch's `User::Accessor` strategy is architecturally elegant -- a single override point provides coverage across all consumers of `accessible_cards`. The layers approach splits this: policy `relation_scope` covers controller collections, but models with their own queries (Filter, Search, Export) still need explicit filtering.

### Commit 3: min_role Generalization

**Base approach**: Replaces boolean with `min_role` string, adds `ROLE_LEVELS` map to `User::Role`, rewrites `visible_to` scopes. The Accessor overrides continue to provide implicit coverage. Dead code introduced: `role_at_least?` defined but never called.

**Layers approach**: Extracts `Column::Accessible` and `Card::ColumnAccessible` concerns with `ROLE_RANKS`, `accessible_by` scope, and `accessible_to?` predicate. DRYs up inline filtering patterns from C2 into reusable scopes. Policy `relation_scope` updated to use new concerns. Adds authorization to card movement targets (triage, drag-drop) -- genuinely new resource-level authorization that no migration would produce.

**Key difference**: The layers C3 catches the card movement authorization gap (authorizing the *destination column* as a separate resource). The base branch doesn't. Both achieve comparable secondary data path coverage.

---

## Completeness Comparison

### What the layers branch does that the base branch doesn't

1. **Card movement target authorization** -- `Cards::TriagesController` and `Columns::Cards::Drops::ColumnsController` authorize the destination column (`authorize! column, to: :show?`). In the base branch, a contributor could triage or drag a card into a column with a higher `min_role` restriction. This is a real security gap.

2. **Extracted reusable concerns** -- `Column::Accessible` and `Card::ColumnAccessible` centralize the filtering logic. The base branch scatters equivalent logic across `User::Accessor`, `Column.visible_to`, `Card.visible_to`, and `Search::Record`.

### What the base branch does that the layers branch doesn't

1. **Guaranteed controller coverage** -- 27 controllers get `ensure_contributor` explicitly. This doesn't depend on a prior migration being complete. Any controller that processes a mutating action is covered by construction.

2. **`cleanup_on_viewer_demotion` callback** -- When a user is demoted to viewer, their assignments are removed and drafted cards destroyed. The layers branch doesn't handle demotion side effects.

3. **`User::Accessor` implicit coverage** -- The Accessor overrides provide a single-point-of-control for data path filtering. Any code using `user.accessible_cards` automatically gets column-restriction filtering without knowing about it. This is a simpler mental model than the layers branch's split between policy `relation_scope` (controllers) and model concerns (data paths).

### Bugs

**Layers branch: `CardPolicy#manage?` missing column accessibility check**

`manage?` checks `not_viewer?` + board-level `show?` but not column-level access:

```ruby
def manage?
  check?(:not_viewer?) && allowed_to?(:show?, record.board)
end
```

A member could `manage?` a card in an admin-only column. In practice, `set_card` calls `authorize! to: :show?` first (which checks column access and raises 404), so direct exploitation requires bypassing the controller. But the policy rule itself is incorrect -- if any code path checks `manage?` without a prior `show?` check, it would allow unauthorized management.

**Base branch: card movement target not filtered**

`Cards::TriagesController` and `Columns::Cards::Drops::ColumnsController` find the target column with `@card.board.columns.find(params[:column_id])` without checking `visible_to`. A member could triage a card into an admin-only column by knowing the column UUID.

### Shared characteristics

- **`viewer_restricted` column retained in schema** -- intentional. Both branches keep it alongside `min_role` as dropping columns in production is unsafe. Documented for future cleanup.
- **`ROLE_RANKS`/`ROLE_LEVELS` missing `system` role** -- both branches rely on the `admin?` bypass triggering first. Fragile but not a runtime issue.
- **Two migrations for the same concept** -- `add_hidden_from_viewers`/`add_viewer_restricted` + `replace_with_min_role`. Expected from iterative development; could be squashed before merge.

---

## Technical Debt Comparison

### Base branch debt

| Item | Severity | Description |
|------|----------|-------------|
| Scattered guards | High | 27 controllers with `before_action :ensure_contributor` -- each is a maintenance point for new endpoints |
| `contributor?` helper | Medium | View-layer authorization via helper method exists outside centralized logic |
| Dead code | Low | `role_at_least?` defined but never called |
| Card movement gap | Medium | Triage/drag-drop don't check target column accessibility |
| Stale docs | Low | Solution docs reference `hidden_from_viewers` which no longer exists |

### Layers branch debt

| Item | Severity | Description |
|------|----------|-------------|
| `manage?` missing column check | Medium | `CardPolicy#manage?` doesn't verify column accessibility |
| `ROLE_RANKS` missing roles | Low | Would crash on `system`/`owner` role if bypass removed |
| `ColumnPolicy#show?` redundant | Low | Double board-level check (manage? then show?) |
| Stale docs | Low | Same as base |

**Assessment**: The base branch's debt is dominated by the 27-controller scatter pattern (ongoing maintenance cost) and the card movement gap (security-relevant). The layers branch's debt is concentrated in the `manage?` policy bug (fixable with one line). The layers branch's debt is more localized and easier to address.

---

## Reviewability Analysis

### As a human reviewer, which is easier to review?

#### Commit 1 (Viewer Role)

| Dimension | Base | Layers |
|-----------|------|--------|
| Files to review | 62 | 36 |
| Controller changes | 31 | 3 |
| Cognitive load | High -- must verify each of 27 controllers has the right `only:`/`except:` options | Low -- verify 6 policy rules, framework propagates them |
| Risk of oversight | High -- easy to miss one controller or get `only:` wrong | Low -- if policy is correct, coverage is automatic |
| Test confidence | Good -- dedicated 309-line test file exercises each endpoint | Good -- policy unit tests per resource |

**Verdict**: The layers version is dramatically easier to review. 6 policy files vs. 31 controller guards.

#### Commit 2 (Per-Column Viewer Access)

| Dimension | Base | Layers |
|-----------|------|--------|
| Files to review | 27 | 23 |
| Core insight needed | Understand that `Accessor` overrides cover all `accessible_cards` consumers | Verify policy `relation_scope` + model-level filters |
| Risk of oversight | Low if reviewer understands Accessor pattern | Moderate -- must trace model-level filters |

**Verdict**: Similar complexity. The base branch's `User::Accessor` override is a single-point solution; the layers branch splits between policy scopes and model concerns.

#### Commit 3 (min_role)

| Dimension | Base | Layers |
|-----------|------|--------|
| Files to review | 23 | 29 |
| New abstractions | 0 | 2 (Column::Accessible, Card::ColumnAccessible) |
| Security gaps addressed | 0 | 2 (triage + drag-drop target authorization) |

**Verdict**: The layers C3 is larger but catches more. The extracted concerns make the pattern clear, and the card movement authorization is genuinely new security coverage.

### Overall reviewability

For a **total PR review** (all 3 commits squashed):

- **Base**: 91 files, 35 controllers modified. A reviewer must verify each controller's `only:`/`except:` configuration, understand the Accessor override pattern, and mentally check card movement endpoints.

- **Layers**: 57 feature files, 8 controllers, 7 policy files. A reviewer can focus on policy files as the source of truth, verify concerns in 2 model files, and trust framework propagation.

**The layers branch is approximately 40-50% less effort to review.** With a complete AP migration, the "unaudited migration" risk from v2 is eliminated, making the layers advantage cleaner.

---

## Evolution Path Optimality

### Which evolution was more optimal?

**C1 evolution**: Layers wins clearly. 6 policy files vs. 31 controller guards.

**C2 evolution**: Base wins slightly. `Accessor` overrides provide broader implicit coverage than the layers branch's split approach (policy scopes for controllers, inline filters for models). The layers branch acknowledged duplication and deferred cleanup to C3.

**C3 evolution**: Layers wins. Extracted concerns DRY up C2 duplication. Card movement authorization is genuinely new coverage. The base C3 is smaller but leaves the movement gap and introduces dead code.

**Overall**: The layers path is more optimal across the full evolution. With a complete AP migration, the advantage is larger than v2 estimated -- the `authorized_scope` pattern eliminates most C2/C3 controller changes that v2 still counted.

---

## AI-Driven vs Human-Involved Development

### Fully AI-driven scenario

- **Base branch**: The AI's mechanical approach (add `before_action` to every controller) is comprehensive by construction. The `Accessor` override pattern in C2 is effective for secondary paths. Risk: the AI misses card movement target authorization, which happened.

- **Layers branch**: The policy framework guides the AI to think resource-by-resource. With `authorized_scope` in place, the AI focuses on policy rules and model-level concerns, not controller plumbing. Risk: the AI introduces a subtle policy-level bug (`manage?` missing column check).

**Assessment**: With a complete AP migration, the layers branch is more AI-friendly. The AI writes fewer controller changes, concentrates on policy logic, and the framework handles propagation. The base branch requires the AI to mechanically touch 31 controllers -- error-free but tedious and fragile.

### Human-involved scenario ("last 10%")

- **Base branch**: 91 files, two patterns to verify (guards + Accessor). The card movement gap is the main thing to catch.

- **Layers branch**: 57 feature files with policies as the primary review surface. Must spot the `manage?` bug. But with only 8 controllers to review, the surface is much smaller.

**Advantage: Layers.** The review surface is nearly halved. The `manage?` bug is subtle but concentrated in one file. The base branch's movement gap requires the reviewer to think about cross-resource authorization in a codebase without a framework for expressing it.

### The compounding effect

With a complete AP migration, the compounding effect is stronger than v2 suggested:

- The base branch's 27-controller scatter from C1 is permanent debt. Every new controller needs `ensure_contributor`. The `Accessor` pattern compounds positively for data paths.

- The layers branch's policy rules compound positively for all authorization logic. `authorized_scope` compounds positively for collections. Only model-level data paths (Filter, Search, Export) require per-path work.

**The layers advantage compounds for both C1-type (role rules) and C2/C3-type (collection filtering) changes**, because `authorized_scope` eliminates controller-level collection filtering that v2 still required.

---

## Summary of Findings

### Phase Matrix

File counts: controllers / views / models / policies / helpers / tests+fixtures / migrations+schema / docs

| | C1: Viewer Role | C2: Per-Column Access | C3: min_role | Total |
|---|---|---|---|---|
| **Base: files** | 62 (31/15/2/0/2/10/0/2) | 27 (5/8/5/0/0/4/3/2) | 23 (4/4/6/0/0/5/2/2) | 91 |
| **Base: problems** | 0 bugs, 0 dead code | 0 bugs | 1 bug (movement target), 1 dead method | 1 bug, 1 dead method |
| **Layers: files** | 36 (3/10/1/6/1/10+3/0/2) | 23 (3/3/3/2/0/7/3/2) | 29 (5/2/8/2/0/7+1/2/2) | 67 |
| **Layers: problems** | 0 bugs, 0 dead code | 0 bugs | 1 bug (`manage?` column check), 0 dead code | 1 bug, 0 dead code |
| **Edge** | **Layers** (31 vs 3 controllers) | **Tie** (Accessor vs policy scopes) | **Layers** (movement auth, concerns) | **Layers** |

### Key Takeaway

The choice of authorization architecture (ad-hoc guards vs. policy framework) has its strongest impact on **rule-based authorization changes** (C1: adding a new role). With a properly completed Action Policy migration including `authorized_scope`, the advantage extends to **collection filtering** (C2/C3), where policy `relation_scope` eliminates most controller-level changes.

The policy framework reduces review surface area by ~40-50% and makes authorization rules easier to reason about. Data path filtering in models (Filter, Search, Export) still requires explicit work regardless of architecture.

The base branch's scatter-guard pattern is its primary liability. The base branch's `User::Accessor` pattern is an underappreciated strength for data-path filtering. Both implementations achieved comparable functional completeness, with small but different security gaps.

---

## Resolved Questions

1. ~~Should the `viewer_restricted` column be removed?~~ No -- dropping columns in production is unsafe. Document for future cleanup.
2. ~~Should `CardPolicy#manage?` include a column check?~~ Yes -- confirmed as a real bug.
3. ~~Are reactions blocked intentionally?~~ Yes -- intentional behavior.

---

## Appendix: Migration-Gap Files

The following files in the layers branch fix pre-existing Action Policy migration gaps (missing `authorize!` calls, absent `authorized_scope` usage, style violations). They are excluded from adjusted file counts.

### C1 gaps (5 files)

| File | What it fixes |
|------|---------------|
| `boards_controller.rb` | Tightened `verify_authorized except` list -- `new`/`create` were already authorized but not verified |
| `cards/publishes_controller.rb` | Changed `:publish?` to `:manage?` -- custom rule violated STYLE.md's CRUD-only convention |
| `cards/columns_controller.rb` | Replaced `skip_authorization` placeholder with real `authorize!` call |
| `boards/show.html.erb` | Hid edit link behind `allowed_to?(:manage?)` -- was visible to all users including members |
| `my/menus/_settings.html.erb` | Hid settings link behind `allowed_to?(:manage?)` -- gates on admin status, not viewer-specific |

### C2 gaps (1 file)

| File | What it fixes |
|------|---------------|
| `prompts/cards_controller.rb` | Inline viewer filter should be `authorized_scope` applying `CardPolicy#relation_scope` |

### C3 gaps (5 files, 2 overlap with C1/C2)

| File | What it fixes |
|------|---------------|
| `boards/columns/closeds_controller.rb` | `column_accessible_by` should be `authorized_scope` applying `CardPolicy#relation_scope` |
| `boards/columns/not_nows_controller.rb` | Same as above |
| `cards/columns_controller.rb` | `accessible_by` should be `authorized_scope` applying `ColumnPolicy#relation_scope` |
| `cards_controller.rb` | `set_card` should already use `authorize! to: :show?`; `edit`/`update` should already use `authorize! to: :manage?` |
| `prompts/cards_controller.rb` | Replaces C2's inline filter with `column_accessible_by` -- still should be `authorized_scope` |

### Mixed files (counted in feature totals, gap portion noted)

| File | Feature portion | Gap portion |
|------|----------------|-------------|
| `boards/columns_controller.rb` (C2+C3) | Permitting `viewer_restricted`/`min_role` param | Index scope filtering (should be `authorized_scope`) |

### Unique gap-only files: 9 (7 controllers, 2 views)
