# Architecture Comparison: Viewer Role Implementation (v2)

**Date:** 2026-02-22
**Status:** Analysis Complete (corrected)
**Previous version:** `2026-02-21-viewer-role-architecture-comparison-brainstorm.md`

---

## Executive Summary (2 slides)

### Slide 1: The Experiment

Two AI agents implemented the same 3-step feature on the same codebase with different architectures:

| | **Base** (vanilla Rails) | **Layers** (Action Policy) |
|---|---|---|
| **Starting point** | Ad-hoc `before_action` guards, model predicates | Policy objects, `authorize!` in controllers |
| **Feature** | Viewer role + per-column access + role-tiered column restrictions |
| **Files changed** | 91 | 64 |
| **Controllers touched** | 35 | 13 |
| **Security bugs** | Card movement target unfiltered | `CardPolicy#manage?` missing column check |
| **Secondary data paths** | All covered (via `User::Accessor`) | All covered (via inline filters + concerns) |

### Slide 2: The Takeaway

**Where layered architecture wins**: Role-based authorization rules (C1). Adding a new role touched 6 policy files vs. 28 controller guards. Review effort ~30-40% lower. Fewer files = fewer places to miss.

**Where vanilla Rails holds its own**: Data-path filtering (C2/C3). The `User::Accessor` override pattern provides implicit coverage across all consumers with a single override point -- the layers branch had to find and filter each path individually.

**The real insight**: Architecture choice has the strongest impact on **rule-based changes** (who can do what). It matters less for **data-path changes** (what can be seen where). Both AIs missed something different -- neither architecture prevents bugs, but the layered version makes them easier to find and fix (one policy file vs. 27 controllers).

---

## Methodology Note

The layers branch's base (`vova-layers`) had an automatic, unaudited Action Policy migration. Some controller/view changes in the feature commits fix pre-existing migration gaps rather than implement the viewer feature. We exclude these (4 files in C1: 2 controllers, 2 views) and show **adjusted** numbers throughout. See [Appendix: Migration-Gap Files](#appendix-migration-gap-files) for details.

---

## What We're Comparing

Two implementations of the same three-step feature built on different architectural foundations:

- **Base branch** (`viewer/base/compound-v3` from `vova-main`): Classic 37signals/DHH Rails -- ad-hoc `before_action` guards, model predicates, `User::Accessor` overrides. No authorization framework.
- **Layers branch** (`viewer/layers/compound-v3` from `vova-layers`): Layered architecture with Action Policy -- policy objects, `authorize!` calls, `allowed_to?` in views. Authorization framework pre-installed (automatic migration, not audited).

Feature requirements evolved identically across three commits:

1. **Viewer role** -- read-only users who can view boards/cards, comment only on triage cards
2. **Per-column viewer access** -- board admins can hide columns from viewers
3. **min_role for columns** -- generalize to role-tiered column access (viewer < member < admin)

---

## Statistical Overview

### Change Matrix (files changed / insertions / deletions)

|                | Base branch         | Layers branch       |
|----------------|---------------------|---------------------|
| Commit 1       | 62 / +1,242 / -115  | ~37 / +1,123 / -87  |
| Commit 2       | 27 / +695 / -18     | 24 / +675 / -18     |
| Commit 3       | 23 / +751 / -122    | 34 / +763 / -105    |
| **Net total**  | **91 / +2,569 / -136** | **~64 / +2,464 / -113** |

### Files by Category (net total)

| Category    | Base | Layers |
|-------------|------|--------|
| Models      | 7    | 9      |
| Controllers | 35   | 13     |
| Views       | 23   | 13     |
| Policies    | 0    | 7      |
| Helpers     | 2    | 1      |
| Tests       | 10   | 15     |
| Fixtures    | 4    | 4      |
| Migrations  | 2    | 2      |
| **Total**   | **83** | **64** |

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

**Layers approach**: Added `not_viewer?` check to `ApplicationPolicy`, then overrode `create?`/`manage?` in 6 policy files. ~3 controllers needed feature-specific changes (settings tightening, reaction policy delegation, role selector update). Views use `allowed_to?` instead of a new helper.

> **Note**: The layers branch benefits from `authorize!` calls that already exist in controllers. However, since the Action Policy migration was automatic and unaudited, some controllers may lack proper `authorize!` calls. The base branch's explicit `ensure_contributor` on each controller compensates for this uncertainty by construction -- it doesn't rely on a prior migration being correct.

**Key difference**: The base version touches **35 controllers** total vs **13** in layers. Without a policy framework, every controller endpoint needs an explicit guard. With policies, rules propagate through pre-existing `authorize!` calls -- but only where those calls exist.

### Commit 2: Per-Column Viewer Access

Both branches add a boolean column (`hidden_from_viewers` / `viewer_restricted`) and filter at multiple data paths.

**Base approach**: Adds `visible_to(user)` scopes to Column and Card models, overrides `accessible_columns`/`accessible_cards` in `User::Accessor`. The Accessor overrides provide **implicit coverage** of all data paths that use `user.accessible_cards` (Filter, Search direct lookup, Autocomplete, DataExport). Additionally, `Search::Record` and `DayTimeline` have their own independent filtering.

**Layers approach**: Adds checks in policies (`CardPolicy#show?`, `ColumnPolicy#show?`, `CardPolicy#relation_scope`) and filters in data path models/controllers (Filter, Search::Record, DataExport, Prompts, Searches). Duplicates inline filtering patterns across ~5 locations.

**Key difference**: The base branch's `User::Accessor` strategy is architecturally elegant here -- a single override point provides coverage across all consumers of `accessible_cards`. The layers branch must find and filter each data path individually, leading to more scattered changes but also more explicit coverage.

### Commit 3: min_role Generalization

**Base approach**: Replaces boolean with `min_role` string, adds `ROLE_LEVELS` map to `User::Role`, rewrites `visible_to` scopes. The Accessor overrides continue to provide implicit coverage. Dead code introduced: `role_at_least?` defined but never called.

**Layers approach**: Extracts `Column::Accessible` and `Card::ColumnAccessible` concerns with `ROLE_RANKS`, `accessible_by` scope, and `accessible_to?` predicate. DRYs up the ~5 inline filtering patterns from C2 into reusable scopes. Adds authorization to card movement targets (triage, drag-drop).

**Key difference**: The layers C3 is more thorough -- it fixes card movement authorization gaps (triage/drag-drop target column checks) that the base branch doesn't address. However, both approaches achieve comparable secondary data path coverage.

---

## Completeness Comparison

### What the layers branch does that the base branch doesn't

1. **Card movement target authorization** -- `Cards::TriagesController` and `Columns::Cards::Drops::ColumnsController` authorize the destination column (`authorize! column, to: :show?`). In the base branch, a contributor could triage or drag a card into a column with a higher `min_role` restriction. This is a real security gap.

2. **Extracted reusable concerns** -- `Column::Accessible` and `Card::ColumnAccessible` centralize the filtering logic. The base branch scatters equivalent logic across `User::Accessor`, `Column.visible_to`, `Card.visible_to`, and `Search::Record`.

### What the base branch does that the layers branch doesn't

1. **Guaranteed controller coverage** -- 27 controllers get `ensure_contributor` explicitly. This doesn't depend on a prior migration being complete. Any controller that processes a mutating action is covered by construction. The layers branch relies on `authorize!` calls that should exist but may not (unaudited migration).

2. **`cleanup_on_viewer_demotion` callback** -- When a user is demoted to viewer, their assignments are removed and drafted cards destroyed. The layers branch doesn't handle demotion side effects.

3. **`User::Accessor` implicit coverage** -- The Accessor overrides provide a single-point-of-control for data path filtering. Any code using `user.accessible_cards` automatically gets column-restriction filtering without knowing about it. This is a simpler mental model than the layers branch's approach of filtering at each individual consumer.

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
| Unaudited AP migration | Medium | Some controllers may lack `authorize!` calls from the initial migration |
| Stale docs | Low | Same as base |

**Assessment**: The base branch's debt is dominated by the 27-controller scatter pattern (ongoing maintenance cost) and the card movement gap (security-relevant). The layers branch's debt is concentrated in the `manage?` policy bug (fixable with one line) and the unaudited migration (systemic but not feature-specific). The layers branch's debt is more localized and easier to address.

---

## Reviewability Analysis

### As a human reviewer, which is easier to review?

#### Commit 1 (Viewer Role)

| Dimension | Base | Layers |
|-----------|------|--------|
| Files to review | 62 | ~37 |
| Controller changes | 28 | 3 feature |
| Cognitive load | High -- must verify each of 27 controllers has the right `only:`/`except:` options | Low -- verify 6 policy rules, trust framework propagation |
| Risk of oversight | High -- easy to miss one controller or get `only:` wrong | Medium -- relies on unaudited AP migration being complete |
| Test confidence | Good -- dedicated 309-line test file exercises each endpoint | Good -- policy unit tests per resource |

**Verdict**: The layers version is significantly easier to review. Reviewing 6 policy files with clear rules vs. verifying 28 controllers each have correct guard configuration is a major cognitive load difference. The risk is different in kind: the base reviewer asks "did they cover every endpoint?" while the layers reviewer asks "was the prior migration complete?" -- but the latter question is out of scope for this feature review.

#### Commit 2 (Per-Column Viewer Access)

| Dimension | Base | Layers |
|-----------|------|--------|
| Files to review | 27 | 24 |
| Core insight needed | Understand that `Accessor` overrides cover all `accessible_cards` consumers | Must verify each data path individually |
| Risk of oversight | Low if reviewer understands Accessor pattern | Moderate -- must trace each inline filter |

**Verdict**: The base branch is arguably *easier* to review here. The `User::Accessor` override strategy means a reviewer who understands that pattern can verify coverage with one question: "does this data path use `accessible_cards`?" The layers branch requires tracing ~5 independent inline filters and verifying each is correct.

#### Commit 3 (min_role)

| Dimension | Base | Layers |
|-----------|------|--------|
| Files to review | 23 | 34 |
| New abstractions | 0 | 2 (Column::Accessible, Card::ColumnAccessible) |
| Security gaps addressed | 0 | 2 (triage + drag-drop target authorization) |

**Verdict**: The layers C3 is larger but catches more. The base C3 is smaller but leaves the card movement gap. A thorough reviewer of either version should catch the gap, but the layers branch preempts it.

### Overall reviewability

For a **total PR review** (all 3 commits squashed):

- **Base**: 91 files, 35 controllers modified. A reviewer must verify each controller's `only:`/`except:` configuration is correct, understand the Accessor override pattern for secondary paths, and mentally check card movement endpoints. The review surface is large but conceptually straightforward -- two patterns to verify (guards + Accessor).

- **Layers**: 64 feature files, 13 controllers, 7 policy files. A reviewer can focus on policy files as the source of truth, verify concerns in 2 model files, and trust framework propagation. Fewer files but relies on trust in the AP migration. Must also spot the `manage?` column-check bug.

**The layers branch is approximately 30-40% less effort to review**, accounting for the base branch's actual completeness via `Accessor`.

---

## Evolution Path Optimality

### Which evolution was more optimal?

The layers branch had a structural advantage: Action Policy provided a centralized place to express authorization rules. This meant C1 required fewer files and C3's concern extraction was a natural evolution.

The base branch had a different structural advantage in C2: the `User::Accessor` override pattern provided implicit coverage across all data paths with a single override. The layers branch had to find and filter each path individually (and then DRY it up in C3).

**C1 evolution**: Layers wins clearly. 6 policy files vs. 28 controller guards.

**C2 evolution**: Base wins slightly. `Accessor` overrides provide broader implicit coverage than the layers branch's per-path inline filters. The layers branch acknowledged this duplication and deferred cleanup to C3.

**C3 evolution**: Layers wins. Extracted concerns (`Column::Accessible`, `Card::ColumnAccessible`) DRY up the C2 duplication. Additionally caught card movement authorization gaps. The base branch's C3 is simpler but doesn't address the movement gap.

**Overall**: The layers path is more optimal across the full evolution, but the margin is smaller than v1 claimed. The base branch's `Accessor` pattern in C2 is an underappreciated strength that provides comparable secondary-path coverage with less per-file work.

---

## AI-Driven vs Human-Involved Development

### Fully AI-driven scenario

- **Base branch**: The AI's mechanical approach (add `before_action` to every controller) is actually comprehensive -- it achieves correct coverage by construction. The `Accessor` override pattern in C2 is also effective for secondary paths. The risk: the AI misses card movement target authorization (triage into restricted columns), which happened.

- **Layers branch**: The policy framework guides the AI to think resource-by-resource. But in C2, the AI had to manually find each data path and add inline filters -- the policy framework doesn't automatically cover data paths. The AI did catch the card movement gap in C3 but introduced a bug in `CardPolicy#manage?`.

**Assessment: Closer to a tie than v1 suggested.** The base branch's `Accessor` strategy is AI-friendly (single override = broad coverage). The layers branch's policy framework is AI-friendly for authorization rules but doesn't help with data path filtering. Both AI implementations missed something: base missed movement targets, layers missed the `manage?` column check.

### Human-involved scenario ("last 10%")

- **Base branch**: The human reviewer faces 91 files but two clear patterns: (1) verify `ensure_contributor` on each controller, (2) verify `Accessor` overrides cover data paths. The card movement gap is the main thing to catch. A 37signals-experienced reviewer familiar with the `Accessor` pattern would find this manageable.

- **Layers branch**: The human reviewer faces 64 feature files with policies as the primary review surface. Fewer files, but must spot the `manage?` bug (a subtle policy-level issue). Must also trust the unaudited AP migration or audit it separately.

**Advantage: Layers, moderately.** Fewer files and a clearer authorization model, but the `manage?` bug is harder to spot than the base branch's missing movement target check. The human effort difference is real but smaller than v1's estimate.

### The compounding effect

Over multiple iterations (C1 -> C2 -> C3), the architectural advantage compounds differently than v1 suggested:

- The base branch's `Accessor` pattern is actually a strength that compounds positively -- new data paths that use `accessible_cards` automatically inherit column filtering. The 27-controller scatter from C1 is the main debt that compounds negatively.

- The layers branch's policy rules compound positively for authorization logic, but data path filtering (Filter, Search, Export, Timeline) still requires per-path work regardless of the authorization framework.

**The real compounding advantage of the layers branch is in C1-type changes** (adding new role restrictions, resource-level access rules). For C2/C3-type changes (data path filtering, scope extraction), both architectures have comparable effort.

---

## Summary of Findings

### Phase Matrix

File counts: controllers / views / models / policies / helpers / tests+fixtures / migrations+schema / docs

| | C1: Viewer Role | C2: Per-Column Access | C3: min_role | Total |
|---|---|---|---|---|
| **Base: files** | 62 (31/15/2/0/2/10/0/2) | 27 (5/8/5/0/0/4/3/2) | 23 (4/4/6/0/0/5/2/2) | 91 |
| **Base: problems** | 0 bugs, 0 dead code | 0 bugs | 1 bug (movement target), 1 dead method | 1 bug, 1 dead method |
| **Layers: files** | ~37 (4/10/1/6/1/10+3/0/2) | 24 (4/3/3/2/0/7/3/2) | 34 (10/2/8/2/0/7+1/2/2) | ~64 |
| **Layers: problems** | 0 bugs, 0 dead code | 0 bugs, 5 duplicated inline filters | 1 bug (`manage?` column check), 0 dead code | 1 bug, 0 dead code |
| **Edge** | **Layers** (31 vs 4 controllers) | **Tie** (Accessor vs per-path) | **Layers** (movement auth, concerns) | **Layers** |

### Key Takeaway

The choice of authorization architecture (ad-hoc guards vs. policy framework) has its strongest impact on **rule-based authorization changes** (C1: adding a new role). The advantage diminishes for **data-path filtering changes** (C2: column visibility), where the base branch's `User::Accessor` pattern proves equally effective. The advantage returns for **generalization/refactoring** (C3), where the policy framework's explicit structure guides extraction of clean, reusable abstractions.

The policy framework reduces review surface area by ~30-40% and makes role-based authorization rules easier to reason about. But it's not a silver bullet -- data path filtering, card movement authorization, and policy-level bugs (`manage?` missing column check) still require manual attention regardless of the framework.

The base branch's scatter-guard pattern is its primary liability. The layers branch's unaudited migration is a latent risk. Both implementations achieved comparable functional completeness, with small but different security gaps.

---

## Resolved Questions

1. ~~Should the `viewer_restricted` column be removed?~~ No -- dropping columns in production is unsafe. Document for future cleanup.
2. ~~Should `CardPolicy#manage?` include a column check?~~ Yes -- confirmed as a real bug.
3. ~~Are reactions blocked intentionally?~~ Yes -- intentional behavior.

---

## Appendix: Migration-Gap Files

The following files in the layers C1 commit fix pre-existing Action Policy migration gaps, not viewer-specific work. They are excluded from adjusted file counts:

| File | What it fixes |
|------|---------------|
| `boards_controller.rb` | Tightened `verify_authorized except` list -- `new`/`create` were already authorized but not verified |
| `cards/publishes_controller.rb` | Changed `:publish?` to `:manage?` -- custom rule violated STYLE.md's CRUD-only convention |
| `boards/show.html.erb` | Hid edit link behind `allowed_to?(:manage?)` -- was visible to all users including members |
| `my/menus/_settings.html.erb` | Hid settings link behind `allowed_to?(:manage?)` -- gates on admin status, not viewer-specific |

Additionally, `cards/columns_controller.rb` (C1) replaced a `skip_authorization` placeholder with real authorization -- primarily a migration fix, but kept in feature counts as it also appears in C3 with feature work.
