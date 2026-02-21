---
title: Column Viewer Restrictions — Secondary Data Path Bypass
date: 2026-02-21
category: security-issues
tags: [authorization, viewer-role, column-restrictions, accessible-cards, data-leakage]
severity: medium
modules: [policies, controllers, models, exports, search, prompts]
symptoms: [data-leakage, restricted-column-cards-visible-to-viewers]
root_cause: accessible-cards-association-lacks-column-level-filtering
---

# Column Viewer Restrictions — Secondary Data Path Bypass

## Problem Statement

When adding `viewer_restricted` boolean to columns (to hide columns and their cards from viewer-role users), the core policy layer (`ColumnPolicy#show?`, `CardPolicy#show?`, `CardPolicy#relation_scope`) was correctly implemented. However, several secondary data paths still leaked restricted content to viewers because they use the raw `user.accessible_cards` association, which provides board-level filtering but has no awareness of column-level restrictions.

## Root Cause

The `User::Accessor` concern defines:

```ruby
has_many :accessible_cards, through: :boards, source: :cards
```

This association is **board-aware** but **column-blind**. Every consumer of `accessible_cards` must independently add viewer_restricted filtering. When a new access dimension is added, it's easy to miss secondary data paths because:

1. The primary authorization layer (policies) enforces restrictions correctly
2. The convenience association provides no hints that additional filtering is needed
3. Each code path must be discovered and patched individually
4. Tests often focus on policy compliance, not on secondary data aggregation

## Affected Data Paths

### 1. JSON API — `Boards::ColumnsController#index`

**File**: `app/controllers/boards/columns_controller.rb`

Returned all columns in JSON response, exposing restricted column names and IDs to viewers.

```ruby
# Fix: filter for viewers
def index
  @columns = @board.columns.sorted
  @columns = @columns.where(viewer_restricted: false) if Current.user.viewer?
  fresh_when etag: @columns
end
```

### 2. Card Autocomplete — `Prompts::CardsController`

**File**: `app/controllers/prompts/cards_controller.rb`

`published_cards` and `prepending_exact_matches_by_id` both used `accessible_cards` without column filtering. Viewers could discover restricted card titles via @mention autocomplete.

```ruby
# Fix: filter published_cards for viewers
def published_cards
  result = Current.user.accessible_cards.published
  if Current.user.viewer?
    result.left_joins(:column)
      .where(columns: { viewer_restricted: false })
      .or(result.left_joins(:column).where(column_id: nil))
  else
    result
  end
end

# Fix: use published_cards (not raw accessible_cards) for exact match
def prepending_exact_matches_by_id(cards)
  if card_by_id = published_cards.find_by(number: params[:filter])
    [ card_by_id ] + cards
  else
    cards
  end
end
```

### 3. Data Exports — `User::DataExport#exportable_cards`

**File**: `app/models/user/data_export.rb`

Viewer's data export ZIP included full card content (title, description, comments, attachments) from restricted columns.

```ruby
# Fix: filter for viewer exports
def exportable_cards
  result = user.accessible_cards.includes(...)

  if user.viewer?
    result.left_joins(:column)
      .where(columns: { viewer_restricted: false })
      .or(result.left_joins(:column).where(column_id: nil))
  else
    result
  end
end
```

### Deferred (MVP Trade-offs)

- **Notifications**: Existing notifications for restricted-column cards produce 404 when clicked. Acceptable for MVP per plan.
- **Pins**: Pinned cards in restricted columns show in pin tray but 404 on click. Same rationale.

## Filtering Pattern

The standard pattern for column-level viewer restriction:

```ruby
if user.viewer?
  result.left_joins(:column)
    .where(columns: { viewer_restricted: false })
    .or(result.left_joins(:column).where(column_id: nil))
else
  result
end
```

Key details:
- `left_joins(:column)` — outer join handles cards with `column_id: nil` (triage, postponed)
- `.or(...where(column_id: nil))` — ensures triage cards remain visible
- Column has `null: false, default: false` so `nil` values for `viewer_restricted` itself are impossible

## Audit Checklist

When adding a new access control dimension, run this checklist:

### Find all consumers

```bash
grep -rn "\.accessible_cards" app/ --include="*.rb" | grep -v "has_many :accessible"
```

### For each consumer, verify

- [ ] Does it apply the new dimension filter?
- [ ] Is it a JSON API endpoint? (audit response data)
- [ ] Is it a background job or export? (check serialization)
- [ ] Is it a search/autocomplete context? (check both text and exact-match paths)
- [ ] Is there a test for the restricted case?

### Current consumers as of 2026-02-21

| Consumer | File | Filtered? |
|----------|------|-----------|
| `Filter#cards` | `app/models/filter.rb` | Yes |
| `SearchesController#show` | `app/controllers/searches_controller.rb` | Yes |
| `Prompts::CardsController` | `app/controllers/prompts/cards_controller.rb` | Yes (this fix) |
| `User::DataExport` | `app/models/user/data_export.rb` | Yes (this fix) |
| `Cards::BoardsController#set_card` | `app/controllers/cards/boards_controller.rb` | Protected via `authorize! to: :manage?` |

## Prevention Strategies

1. **Audit all `accessible_cards` consumers** when adding access dimensions — use the grep command above
2. **Consider extracting a shared scope** on `Card` to DRY the filtering pattern (currently duplicated in 5 places)
3. **Use `allowed_to?` in controllers** instead of inline `viewer?` checks — delegates to the policy as single source of truth
4. **Add bypass tests for secondary paths** — test that restricted content is excluded from JSON, autocomplete, exports, and search

## Related Documentation

- [`docs/solutions/security-issues/authorization-gaps-viewer-role-action-policy.md`](authorization-gaps-viewer-role-action-policy.md) — Original viewer role authorization gap audit (10 gaps found)
- [`docs/solutions/action-policy-authorization-patterns.md`](../action-policy-authorization-patterns.md) — Action Policy patterns (relation_scope, check?, allowed_to?)
- [`docs/solutions/action-policy-migration-pitfalls.md`](../action-policy-migration-pitfalls.md) — `.or()` structural compatibility, find-then-authorize patterns
