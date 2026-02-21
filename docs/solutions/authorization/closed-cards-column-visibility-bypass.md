---
title: Closed cards from hidden columns visible to viewers
date: 2026-02-21
category: authorization
tags:
  - selective-column-visibility
  - viewer-role
  - closed-cards
  - authorization-bypass
  - defense-in-depth
severity: high
modules:
  - Card::Closeable
  - Boards::Columns::ClosedsController
  - Public::Boards::Columns::ClosedsController
symptoms:
  - Viewers see closed cards from hidden columns in the Done section
  - Public board visitors see closed cards from hidden columns
  - Closed card count badge includes cards from hidden columns
root_cause: Closed cards retain column_id when closed, and the closed cards query path bypassed column visibility filtering
---

# Closed cards from hidden columns visible to viewers

## Problem Statement

When implementing "Selective column visibility for viewers," the implementation correctly filtered hidden columns and their cards across active card paths (board view, card detail, search, timeline, filters). However, **closed cards** were still visible to viewers because the closed cards controllers queried `@board.cards.closed` directly, bypassing the `User::Accessor#accessible_cards` override that applies column visibility filtering.

## Investigation Steps

1. **Review identified the gap**: Multi-agent code review flagged that `Boards::Columns::ClosedsController` and `Public::Boards::Columns::ClosedsController` query `@board.cards.closed` without column visibility filtering.

2. **Verified the card lifecycle**: Traced `Card::Closeable#close` — it creates a `Closure` record but does NOT change `column_id`. The card retains its original column reference.

3. **Confirmed postponed cards are safe**: `Card::Postponable#postpone` calls `send_back_to_triage`, which sets `column: nil`. Postponed cards have no column association, so they cannot leak hidden column data.

4. **Confirmed triage cards are safe**: `Card::Triageable` defines `awaiting_triage` as `active.where.missing(:column)`. These cards have no column.

5. **Identified all affected locations**: Two controllers (authenticated + public) and two view count badges.

## Root Cause

Cards retain their `column_id` when closed. The closed cards query path (`@board.cards.closed.recently_closed_first`) goes directly through the board association, bypassing the `User::Accessor#accessible_cards` override that filters hidden columns for viewers.

The existing defense-in-depth covered:
- Column listings (via `Column.visible_to(user)` scope)
- Active card lookups (via `User::Accessor#accessible_cards` override, used by `CardScoped` and `ColumnScoped` concerns)
- Search results (via `Search::Record.for_query` filtering)
- Timeline events (via `User::DayTimeline#timelineable_events` filtering)
- Filters (via `Filter#cards` starting from `accessible_cards`)

But missed:
- Closed cards controllers (query `@board.cards.closed` directly)
- Closed cards count badges in views

## Working Solution

### 1. Added `Card.visible_to(user)` scope

Mirrors the existing `Column.visible_to(user)` pattern:

```ruby
# app/models/card.rb
scope :visible_to, ->(user) {
  if user&.contributor?
    all
  else
    where(column_id: nil).or(
      where.not(column_id: Column.where(hidden_from_viewers: true).select(:id))
    )
  end
}
```

The `where(column_id: nil).or(...)` handles triage/postponed cards (null `column_id`) that should remain visible.

### 2. Applied to controllers

```ruby
# app/controllers/boards/columns/closeds_controller.rb
@board.cards.closed.visible_to(Current.user).recently_closed_first.preloaded

# app/controllers/public/boards/columns/closeds_controller.rb
@board.cards.closed.visible_to(nil).recently_closed_first
```

### 3. Applied to view count badges

```erb
<%# app/views/boards/show/_closed.html.erb %>
board.cards.closed.visible_to(Current.user).count

<%# app/views/public/boards/show/_closed.html.erb %>
board.cards.closed.visible_to(nil).count
```

### 4. Tests

Added 3 tests covering:
- Viewer cannot see closed cards from hidden columns (authenticated)
- Contributor can still see closed cards from hidden columns (authenticated)
- Public board visitors cannot see closed cards from hidden columns

## Prevention Strategies

### Audit checklist for new visibility restrictions

When adding a filtering dimension (column visibility, role restrictions, etc.), audit ALL query paths for the filtered resource:

- [ ] Active/default listing
- [ ] Closed/archived listing
- [ ] Postponed/deferred listing
- [ ] Triage/inbox listing
- [ ] Search results
- [ ] Timeline/activity feed
- [ ] Filters/faceted views
- [ ] Card detail (direct URL access)
- [ ] Count badges in views
- [ ] Export paths
- [ ] Webhook payloads
- [ ] Notification content
- [ ] Public/shared board equivalents of all above

### Key insight

Controllers that query cards through status-based scopes (`.closed`, `.postponed`, `.active`) go directly through the board association and bypass `User::Accessor#accessible_cards`. Each of these paths needs independent filtering when a new visibility dimension is added.

### Testing pattern

For every visibility restriction, write tests that cover cards in non-default states:

```ruby
# Don't just test active cards — test closed cards too
test "viewer cannot see closed cards from hidden columns" do
  card = cards(:in_hidden_column)
  with_current_user(:contributor) { card.close }

  sign_in_as :viewer
  get board_columns_closed_path(board)
  assert_no_match card.title, response.body
end
```

## Related Documents

- [Viewer role read-only access](viewer-role-read-only-access.md) — Foundation for the viewer role defense-in-depth pattern
- [Selective column visibility plan](../../plans/2026-02-21-feat-selective-column-visibility-for-viewers-plan.md) — Implementation plan for the column visibility feature
