# Architecture Comparison: Viewer Role Implementation

**Date:** 2026-02-21
**Status:** Analysis Complete

## What We're Comparing

Two implementations of the same three-step feature (viewer role + per-column access + role-based column restrictions) built on different architectural foundations:

- **Base branch** (`viewer/base/compound-v3` from `vova-main`): Classic 37signals/DHH Rails -- ad-hoc `before_action` guards, model predicates, helper methods. No authorization framework.
- **Layers branch** (`viewer/layers/compound-v3` from `vova-layers`): Layered architecture with Action Policy -- policy objects, `authorize!` calls, `allowed_to?` in views. Authorization framework pre-installed.

The feature requirements evolved identically across three commits in each branch:

1. **Viewer role** -- read-only users who can view boards/cards, comment only on triage cards
2. **Per-column viewer access** -- board admins can hide columns from viewers
3. **min_role for columns** -- generalize to role-tiered column access (viewer < member < admin)

---

## Statistical Overview

### Change Matrix (files changed / insertions / deletions)

|                | Base branch         | Layers branch       |
|----------------|---------------------|---------------------|
| Commit 1       | 62 / +1,242 / -115  | 41 / +1,123 / -87   |
| Commit 2       | 27 / +695 / -18     | 24 / +675 / -18     |
| Commit 3       | 23 / +751 / -122    | 34 / +763 / -105    |
| **Net total**  | **91 / +2,569 / -136** | **76 / +2,464 / -113** |

### Files by Category (net total)

| Category    | Base | Layers |
|-------------|------|--------|
| Models      | 7    | 9      |
| Controllers | 35   | 15     |
| Views       | 23   | 15     |
| Policies    | 0    | 7      |
| Helpers     | 2    | 1      |
| Tests       | 10   | 15     |
| Fixtures    | 4    | 4      |
| Migrations  | 2    | 2      |
| **Total app code** | **83** | **68** |

### Cross-Commit Churn (files modified in 2+ commits)

| Commit pair | Base | Layers |
|-------------|------|--------|
| C1 & C2     | 1    | 3      |
| C2 & C3     | 17   | 19     |
| C1 & C3     | 3    | 4      |

Both branches show significant C2→C3 churn (~17-19 files), which is expected: the boolean `hidden_from_viewers` approach from C2 was generalized to `min_role` in C3.

---

## Architecture Analysis

### Commit 1: Viewer Role

**Base approach**: Created `ensure_contributor` guard in `Authorization` concern, applied it via `before_action` to **27 controllers** individually. Added `contributor?` predicate to `User::Role`, `contributor?` helper for views, and `commentable_by?` to `Card::Commentable`.

**Layers approach**: Added `not_viewer?` check to `ApplicationPolicy`, then overrode `create?`/`manage?` in 6 policy files. Controllers needed minimal changes (6 files) -- adjusting a few `authorize!` calls to use different rules or resource classes. Views use `allowed_to?` instead of a new helper.

> **Note on controller changes in the layers branch**: Some controller modifications in C1 (e.g., adding `CardScoped`, replacing `skip_authorization` with `verify_authorized`) are fixes to pre-existing gaps in the Action Policy migration, not viewer-specific work. The migration to Action Policy was automatic and hasn't been thoroughly audited. We exclude these from the feature comparison -- only changes that add new policy rules or check different resources/rules count as feature work.

**Key difference**: The base version touches **35 controllers** total vs **15** in layers. This is the most dramatic divergence. Without a policy framework, every controller endpoint needs an explicit guard. With policies, the rules propagate automatically through `authorize!` calls that were already present (assuming the initial migration was complete).

### Commit 2: Per-Column Viewer Access

Both branches add a `viewer_restricted` / `hidden_from_viewers` boolean column and filter at multiple data paths (board view, search, autocomplete, exports, public boards).

**Base approach**: Adds `visible_to(user)` scopes to Column and Card models, overrides `accessible_columns`/`accessible_cards` in `User::Accessor`. Filtering applied directly in controllers.

**Layers approach**: Adds filtering in policies (`CardPolicy#show?`, `CardPolicy#relation_scope`, `ColumnPolicy#show?`) and in data path models (Filter, Search::Record, DataExport). Also duplicates inline filtering patterns across ~5 locations.

**Key difference**: Both approaches have similar complexity here. The layers branch benefits from policy-level enforcement but still needs inline filtering in data paths. The duplication in the layers branch is explicitly acknowledged and deferred to C3.

### Commit 3: min_role Generalization

**Base approach**: Replaces boolean with `min_role` string, adds `ROLE_LEVELS` map and `role_at_least?` to `User::Role`, rewrites `visible_to` scopes with role-tier branching. The `role_at_least?` method is defined but never used (dead code).

**Layers approach**: Extracts `Column::Accessible` and `Card::ColumnAccessible` concerns with `ROLE_RANKS`, `accessible_by` scope, and `accessible_to?` predicate. DRYs up the 5+ inline filtering patterns from C2 into reusable scopes. Adds authorization to card movement targets (triage, drag-drop).

**Key difference**: The layers version is more thorough here -- it addresses card movement authorization gaps and extracts shared concerns. The base version leaves more duplication in place and introduces dead code (`role_at_least?`).

---

## Completeness Comparison

### What the layers branch does that the base branch doesn't

1. **Card movement authorization** -- `Cards::TriagesController` and `Columns::Cards::Drops::ColumnsController` authorize the destination column. The base branch has no such check -- a viewer or restricted member could triage/drag a card into a column they can't access.

2. **Activity timeline filtering** -- `User::DayTimeline` excludes events for cards in restricted columns. The base branch doesn't filter the timeline.

3. **Data export filtering** -- `User::DataExport` excludes restricted column cards. Not addressed in the base branch.

4. **Autocomplete/prompt filtering** -- `Prompts::CardsController` filters restricted cards from autocomplete results. Not addressed in the base branch.

5. **Search filtering** -- `SearchesController` filters restricted cards from both fast-path and text search. Not addressed in the base branch.

6. **Filter model** -- `Filter` results exclude restricted column cards. Not addressed in the base branch.

### What the base branch does that the layers branch doesn't

1. **Broader controller coverage for viewer role** -- 27 controllers get `ensure_contributor`, covering endpoints like `Cards::ImagesController`, `Cards::StepsController`, `Cards::TaggingsController`, `Cards::GoldnessesController`, etc. In the layers branch, these are covered implicitly by existing `authorize!` calls in those controllers. Since the Action Policy migration was automatic and not thoroughly audited, some controllers may lack `authorize!` calls -- the base branch's explicit `ensure_contributor` guard catches those gaps by construction.

2. **`cleanup_on_viewer_demotion` callback** -- When a user is demoted to viewer, their drafted cards are destroyed. The layers branch doesn't have this.

### Shared bugs/gaps

1. **`viewer_restricted` column retained in schema** -- Both branches leave the `viewer_restricted` column alongside `min_role`. This is intentional: dropping columns in production is unsafe. The column should be documented as dead and scheduled for removal in a future cleanup migration once all reads/writes are confirmed gone.

2. **`ROLE_RANKS`/`ROLE_LEVELS` missing `system` role** -- Both branches define role ordinal maps that omit the `system` role. Would crash if called on a system user (currently safe because admin bypass triggers first).

### Bugs unique to the layers branch

1. **`CardPolicy#manage?` doesn't check column accessibility** -- `manage?` checks `not_viewer?` + board-level `show?` but not column-level access. A member could `manage?` a card in an admin-only column. In practice, `set_card` calls `authorize! to: :show?` which includes the column check, so direct exploitation requires bypassing the controller flow. But the policy rule itself is incorrect -- `manage?` should include a column accessibility check for correctness and defense-in-depth.

---

## Technical Debt Comparison

### Base branch debt

| Item | Severity | Description |
|------|----------|-------------|
| Scattered guards | High | 27 controllers with `before_action :ensure_contributor` -- each is a potential oversight point for new endpoints |
| `contributor?` helper | Medium | View-layer authorization via helper method bypasses any centralized logic |
| Dead code | Low | `role_at_least?` defined but never called |
| Missing secondary path filtering | High | Search, autocomplete, exports, timeline, filters not updated for column restrictions |
| Two migrations | Low | `add_hidden_from_viewers` + `replace_with_min_role` could be squashed |
| Stale docs | Low | Solution docs reference `hidden_from_viewers` which no longer exists |

### Layers branch debt

| Item | Severity | Description |
|------|----------|-------------|
| `viewer_restricted` in schema | Medium | Dead column still in schema, needs cleanup migration |
| `ROLE_RANKS` missing roles | Low | Would crash on `system` role if bypass is ever removed |
| `manage?` doesn't check column access | Medium | `CardPolicy#manage?` checks `not_viewer?` + board access but not column access |
| `ColumnPolicy#show?` redundant check | Low | Calls both `allowed_to?(:manage?, board)` and `allowed_to?(:show?, board)` |
| Two migrations | Low | Same as base |
| Stale docs | Low | Same as base |

**Assessment**: The base branch carries significantly more structural debt. The 27-controller scatter pattern means every new controller or endpoint requires remembering to add `ensure_contributor`. The missing secondary path filtering is a security-relevant gap. The layers branch's debt is mostly cosmetic or edge-case-only.

---

## Reviewability Analysis

### As a human reviewer, which is easier to review?

#### Commit 1 (Viewer Role)

| Dimension | Base | Layers |
|-----------|------|--------|
| Files to review | 62 | 41 |
| Controller changes | 28 | 6 |
| Cognitive load | High -- must verify each of 27 controllers has the right `only:`/`except:` options | Low -- verify policy rules, trust framework propagation |
| Risk of oversight | High -- easy to miss one controller or get `only:` wrong | Low -- if policy is correct, coverage is automatic |
| Test confidence | Good -- dedicated 309-line test file exercises each endpoint | Good -- policy unit tests + controller integration tests |

**Verdict**: The layers version is dramatically easier to review for C1. Reviewing 6 policy files with clear rules vs. verifying 28 controllers each have the right guard configuration is a major cognitive load difference. A reviewer of the base version needs to mentally check: "Did they cover *every* mutating endpoint?" A reviewer of the layers version needs to check: "Are the policy rules correct?" -- a much simpler question.

#### Commit 2 (Per-Column Viewer Access)

| Dimension | Base | Layers |
|-----------|------|--------|
| Files to review | 27 | 24 |
| Architecture clarity | Clear -- scopes + accessor overrides | Clear -- policies + inline filtering |
| Risk of oversight | Moderate | Moderate |

**Verdict**: Similar complexity. Both branches add filtering at multiple data paths. The layers branch is slightly more reviewable because changes are concentrated in fewer files and the policy layer makes intent explicit.

#### Commit 3 (min_role)

| Dimension | Base | Layers |
|-----------|------|--------|
| Files to review | 23 | 34 |
| New abstractions | 0 | 2 (Column::Accessible, Card::ColumnAccessible) |
| Architectural clarity | Lower -- role branching scattered in scopes | Higher -- extracted concerns with clear responsibilities |
| Completeness | Lower -- misses secondary paths | Higher -- covers triage, drag-drop, timeline |

**Verdict**: The layers C3 is larger but higher quality. The extracted concerns make the pattern clear and the expanded coverage catches real authorization gaps. The base C3 is simpler but leaves gaps.

### Overall reviewability

For a **total PR review** (all 3 commits squashed):

- **Base**: 91 files, 35 controllers modified. A reviewer must trace authorization through ad-hoc guards across 35 controllers, verify each endpoint is covered, and reason about model-level scopes. The lack of a centralized authorization layer makes it hard to answer "is everything covered?"

- **Layers**: 76 files, 15 controllers modified, 7 policy files. A reviewer can focus on policy files as the single source of truth, verify scopes in 2 model concerns, and check secondary path filtering. The policy layer provides a natural checklist: "does each resource have correct rules?"

**The layers branch is approximately 40-50% less effort to review**, measured by files, cognitive surface area, and risk of missing an authorization gap.

---

## Evolution Path Optimality

### Which evolution was more optimal?

The layers branch had a significant structural advantage: Action Policy was already installed with policies for every resource. This meant:

1. **C1 was additive** -- Adding `not_viewer?` to existing policies vs. scattering guards across 27 controllers
2. **C2 was localized** -- Column/card visibility checks added to existing policy rules vs. new model scopes + accessor overrides + controller filtering
3. **C3 was a clean extraction** -- Extracting concerns from established patterns vs. rewriting scattered logic

The base branch's evolution was suboptimal because:

1. **C1 created 27 coupling points** -- Each `ensure_contributor` is a maintenance burden
2. **C2 worked around the lack of policy objects** -- `visible_to` scopes and `User::Accessor` overrides are compensating for the absence of a centralized authorization layer
3. **C3 generalized C2 but couldn't fix C1** -- The `ensure_contributor` scatter from C1 remains unchanged; C3 only generalizes the column visibility, not the fundamental authorization approach

**The layers branch's evolution path is more optimal because each step built cleanly on the previous one.** The base branch accumulated structural debt from C1 that C2 and C3 couldn't address.

---

## AI-Driven vs Human-Involved Development

### Fully AI-driven scenario

In a fully AI-driven workflow (agent writes code, agent reviews, agent merges):

- **Base branch**: The AI can mechanically add `before_action` guards to every controller -- it's tedious but straightforward. The risk is that the AI doesn't identify secondary data paths (search, exports, timeline) as needing filtering, which is exactly what happened in the base branch's C2/C3.

- **Layers branch**: The AI benefits from the policy framework because it provides a natural structure for reasoning about authorization. The AI is more likely to be thorough because the policy pattern forces it to think resource-by-resource rather than endpoint-by-endpoint.

**Advantage: Layers.** The policy framework acts as a scaffold that guides the AI toward completeness. The scatter-guard approach lets the AI "complete" the task without catching all the gaps.

### Human-involved scenario ("last 10%")

In a human-polishing workflow (AI writes first draft, human reviews and fixes):

- **Base branch**: The human reviewer faces a 91-file, 35-controller diff. They must mentally verify coverage of every endpoint, every secondary path, every view conditional. This is exhausting and error-prone. The "last 10%" is likely to take 30-60% of the total effort because the review surface is so large.

- **Layers branch**: The human reviewer faces a 76-file, 15-controller diff with 7 policy files as the source of truth. They can review policies first (10 minutes), then verify secondary paths (10 minutes), then spot-check views (5 minutes). The "last 10%" is genuinely 10% because the architecture makes review tractable.

**Advantage: Layers, dramatically.** The human's time is the most expensive input. Reducing review surface area by 40-50% translates directly to faster iteration and fewer missed bugs.

### The compounding effect

Over multiple iterations (C1 → C2 → C3), the architectural advantage compounds:

- In the base branch, each iteration adds more scattered coupling points. C1 added 27 controller guards; C2 added 5+ model-level scopes; C3 rewrote the scopes. The complexity grows linearly with each feature.

- In the layers branch, each iteration refines the same centralized policies. C1 defined rules; C2 extended them; C3 extracted shared concerns. The complexity stays concentrated in a small number of files that the developer (human or AI) can hold in their head.

---

## Summary of Findings

| Dimension | Base | Layers | Winner |
|-----------|------|--------|--------|
| Total files changed | 91 | 76 | Layers |
| Controller churn | 35 files | 15 files | Layers |
| Authorization completeness | Missing 5+ secondary paths | Comprehensive | Layers |
| Technical debt | High (scattered guards) | Low (cosmetic) | Layers |
| Review effort | ~90 min (estimated) | ~45 min (estimated) | Layers |
| Evolution smoothness | C1 created debt, C3 couldn't fix | Each step built cleanly | Layers |
| Dead code introduced | `role_at_least?` | `viewer_restricted` column | Tie |
| Test coverage | Good for guards, weak for paths | Good for policies, weak for controllers | Tie |

### Key Takeaway

The choice of authorization architecture (ad-hoc guards vs. policy framework) had a **multiplicative effect** on every subsequent change. What started as a modest difference in C1 (62 vs 41 files) compounded into significant gaps in completeness, reviewability, and maintainability by C3. The policy framework didn't just make the code cleaner -- it made the AI more thorough and the human reviewer more effective.

---

## Open Questions

1. Should the `viewer_restricted` column be removed in a follow-up migration, or left as-is?
2. Should `CardPolicy#manage?` include a column accessibility check?
3. Is the reactions-blocked-for-viewers behavior intentional (both branches do it, docs say otherwise)?
