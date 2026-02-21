---
title: "Column Access Control: Secondary Data Path Leaks in NotNows, Timeline, and Policy Inference"
date: 2026-02-21
module:
  - authorization
  - column-restrictions
component:
  - controllers
  - models
  - policies
severity: HIGH
tags:
  - security
  - data-isolation
  - access-control
  - action-policy
  - activity-timeline
  - postponed-cards
  - policy-inference
status: verified
---

# Column Access Control: Secondary Data Path Leaks

## Problem Statement

When implementing per-column role-based access control (`min_role` enum replacing `viewer_restricted` boolean), the primary card/column data paths were correctly filtered but three secondary data paths leaked restricted-column content:

1. **Not Now (postponed) panel** — loaded cards without column filtering
2. **Activity timeline** — loaded events (polymorphic) without checking if the card's column is accessible
3. **CardsController#set_card** — used bare `authorize!` relying on fragile action-name inference

The pattern: `column_accessible_by` scope works for queries that go through Card directly, but paths that query Events or load cards through separate associations need independent filtering.

## Root Cause Analysis

Three distinct data paths each required independent column-access filtering. The core problem: the `column_accessible_by` scope and role-rank filtering exist on the main card/column views, but secondary data paths that render equivalent data were not updated.

The pattern of failure is consistent: a new access control mechanism was added to the primary path, but parallel paths that render the same data were not updated.

### Why secondary paths are missed

- **NotNowsController vs ClosedsController**: Two parallel pseudo-column controllers. The Closed panel was updated; the Not Now panel was not. Copy-paste parity failure.
- **Activity timeline**: Queries `Event` records (polymorphic `eventable`) rather than `Card` records. Card-level scopes don't compose through polymorphic associations.
- **Bare authorize!**: Implicit rule inference from `action_name` works correctly today but is fragile under refactoring. Documented pitfall from prior migration.

## Working Solutions

### Fix 1: NotNowsController Missing Column-Access Filter

**File**: `app/controllers/boards/columns/not_nows_controller.rb`

```ruby
# Before
def show
  set_page_and_extract_portion_from @board.cards.postponed.latest.preloaded
  fresh_when etag: @page.records
end

# After
def show
  set_page_and_extract_portion_from @board.cards.postponed.column_accessible_by(Current.user).latest.preloaded
  fresh_when etag: @page.records
end
```

Single scope insertion. `column_accessible_by(Current.user)` filters cards by column visibility, matching the pattern already used in `ClosedsController`.

### Fix 2: Activity Timeline Leaking Restricted-Column Events

**File**: `app/models/user/day_timeline.rb`

```ruby
# Before
def timelineable_events
  Event
    .preloaded
    .where(board: boards)
    .where(action: TIMELINEABLE_ACTIONS)
end

# After
def timelineable_events
  events = Event
    .preloaded
    .where(board: boards)
    .where(action: TIMELINEABLE_ACTIONS)

  if user.admin?
    events
  else
    rank = Column::Accessible::ROLE_RANKS.fetch(user.role, 0)
    restricted_card_ids = Card.joins(:column).where("columns.min_role > ?", rank).select(:id)

    events
      .where.not(eventable_type: "Card", eventable_id: restricted_card_ids)
      .where.not(eventable_type: "Comment", eventable_id: Comment.where(card_id: restricted_card_ids).select(:id))
  end
end
```

Key details:
- Admins bypass the filter (full column access by definition)
- `restricted_card_ids` uses `.select(:id)` to stay as a SQL subquery
- Two `.where.not` clauses handle both Card events and Comment events (the two eventable types that expose card content)

### Fix 3: CardsController#set_card Bare authorize!

**File**: `app/controllers/cards_controller.rb`

```ruby
# Before
def set_card
  @card = Current.account.cards.find_by!(number: params[:id])
  authorize! @card
end

# After
def set_card
  @card = Current.account.cards.find_by!(number: params[:id])
  authorize! @card, to: :show?
end

def edit
  authorize! @card, to: :manage?
end

def update
  authorize! @card, to: :manage?
  @card.update! card_params
  # ...
end
```

The shared `set_card` applies `show?` (minimum required). Write actions add explicit `authorize! to: :manage?`. Removes reliance on action-name inference per documented pitfall in `docs/solutions/action-policy-migration-pitfalls.md`.

## Key Patterns

**Every data path is its own authorization boundary.** Adding a scope to the main board/column views does not protect secondary endpoints (postponed panels, timelines, exports, API endpoints). Each path that renders card content must independently apply column-access filtering.

**Polymorphic event queries require subquery exclusion.** When a model (like `Event`) references cards indirectly through a polymorphic association, card-level scopes don't apply. Compute a subquery of restricted record IDs and exclude them with `.where.not(eventable_type: "...", eventable_id: subquery)`.

**Shared before_action methods should use the minimum required rule.** A method like `set_card` that runs for all actions should authorize at `show?`. Actions requiring elevated access add a second explicit `authorize!` with `to: :manage?`.

## Prevention Checklist

When adding column-level (or any resource-level) access control, audit these paths:

### Grep-based audit

```bash
# 1. Find all consumers of accessible_cards
grep -rn "\.accessible_cards" app/ --include="*.rb" | grep -v "has_many :accessible"

# 2. Find controllers that load cards without column filtering
grep -rn "\.cards\." app/controllers --include="*.rb" | grep -v "column_accessible_by"

# 3. Find polymorphic loads that might bypass authorization
grep -rn "belongs_to.*polymorphic: true" app/models --include="*.rb"

# 4. Find event/notification/pin queries (secondary models)
grep -rn "\.events\|\.notifications\|\.pins" app/controllers --include="*.rb"

# 5. Find bare authorize! calls (missing explicit rule)
grep -rn "authorize! @" app/controllers --include="*.rb" | grep -v "to:"
```

### Systematic audit

For each secondary model that references Card (Event, Notification, Pin, Comment):

1. **Enumerate all data paths** — controllers, views, jobs, APIs that load the model
2. **Check each path** — does it filter by column access?
3. **Test with restricted user** — sign in as viewer/member, verify restricted data is hidden
4. **Check stale data** — what happens when column restriction is added after the record was created?

### Polymorphic association warning

Polymorphic associations create a hidden authorization blind spot. When you load an `Event` and access `event.card`, the card is lazy-loaded without authorization. The authorization logic lives in `CardPolicy`, not `EventPolicy`. The query must filter before the polymorphic load happens.

## Remaining Known Gaps (Post-MVP)

These secondary paths are documented as accepted MVP trade-offs:

- **Notifications**: Stale notifications after column restriction changes may expose card titles. Filter at read time or clean up on restriction change.
- **Pins tray**: Pre-existing pins for cards moved to restricted columns remain visible. Filter `user_pins` by `column_accessible_by`.
- **Turbo broadcasts**: Card-level stream subscriptions persist if a user is viewing a card when its column restriction changes.

## Related Documentation

- [Column Viewer Restrictions: Secondary Data Path Bypass](column-viewer-restrictions-secondary-data-path-bypass.md) — the original viewer_restricted bypass patterns (predecessor to this document)
- [Authorization Gaps: Viewer Role + Action Policy](authorization-gaps-viewer-role-action-policy.md) — 10 authorization gaps from viewer role implementation
- [Action Policy Migration Pitfalls](../action-policy-migration-pitfalls.md) — bare `authorize!` pitfall (Pitfall 4)
- [Action Policy Authorization Patterns](../action-policy-authorization-patterns.md) — foundational patterns
