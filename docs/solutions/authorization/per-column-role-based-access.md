---
title: Per-Column Role-Based Access Control
date: 2026-02-21
status: documented
module: Column, User::Role, User::Accessor, Card, Search::Record, User::DayTimeline
tags: authorization, access-control, role-based, column-visibility, security
severity: high
---

# Per-Column Role-Based Access Control

## Problem

Fizzy's column visibility was controlled by a binary `hidden_from_viewers` boolean. Columns were either visible to everyone or hidden from viewers only. There was no way to hide columns from members (e.g., a "Leadership" column visible only to admins/owners). The binary approach also couldn't scale to future role distinctions.

## Root Cause

The `hidden_from_viewers` flag only distinguished between two groups: viewers and contributors (`contributor?` = owner/admin/member). The role hierarchy (viewer < member < admin = owner) existed in the User model but wasn't leveraged for column-level access control.

## Solution

Replaced the boolean with a `min_role` string attribute (values: `viewer`/`member`/`admin`, default: `viewer`). Each column now declares the weakest role that can access it. Users with a role below the threshold cannot see the column or any of its resources.

### Schema Change

```ruby
class ReplaceHiddenFromViewersWithMinRole < ActiveRecord::Migration[8.2]
  def change
    add_column :columns, :min_role, :string, default: "viewer", null: false

    reversible do |dir|
      dir.up do
        execute "UPDATE columns SET min_role = 'member' WHERE hidden_from_viewers = TRUE"
      end
      dir.down do
        execute "UPDATE columns SET hidden_from_viewers = TRUE WHERE min_role != 'viewer'"
      end
    end

    remove_column :columns, :hidden_from_viewers, :boolean, default: false, null: false
  end
end
```

Data mapping: `hidden_from_viewers: true` becomes `min_role: "member"`. Rollback is lossy — `min_role: "admin"` collapses to `hidden_from_viewers: true`.

### Column Model

```ruby
class Column < ApplicationRecord
  MIN_ROLES = %w[ viewer member admin ].freeze

  validates :min_role, inclusion: { in: MIN_ROLES }

  scope :visible_to, ->(user) {
    if user&.admin?
      all
    elsif user&.member?
      where(min_role: %w[viewer member])
    elsif user&.viewer?
      where(min_role: "viewer")
    else
      where(min_role: "viewer")
    end
  }

  scope :publicly_visible, -> { where(min_role: "viewer") }

  def restricted?
    min_role != "viewer"
  end
end
```

### User::Accessor

```ruby
def accessible_columns
  if admin?
    super
  else
    super.visible_to(self)
  end
end

def accessible_cards
  if admin?
    super
  else
    visible_column_ids = Column.where(board_id: board_ids).visible_to(self).select(:id)
    super.where(column_id: [nil]).or(super.where(column_id: visible_column_ids))
  end
end
```

### Card.visible_to

```ruby
scope :visible_to, ->(user) {
  if user&.admin?
    all
  else
    visible_column_ids = Column.visible_to(user).select(:id)
    where(column_id: nil).or(where(column_id: visible_column_ids))
  end
}
```

### Search and Timeline

Both `Search::Record.for_query` and `User::DayTimeline#timelineable_events` changed from `unless user.contributor?` to `unless user.admin?`, using `Column.visible_to(user)` to compute which columns (and therefore cards) to filter.

### Controller — min_role Gated to Board Admins

```ruby
def column_params
  attrs = params.expect(column: [ :name, :color, :min_role ])
  attrs.delete(:min_role) unless Current.user.can_administer_board?(@board)
  attrs
end
```

### Views

- Column form: checkbox replaced with `<select>` dropdown for `min_role`
- Column header: badge shows "Members only" or "Admins only" when `restricted?`
- Public views: `viewer_visible` renamed to `publicly_visible`
- Card column selector (`Cards::ColumnsController#edit`): filtered with `visible_to(Current.user)` so members don't see admin-only columns when triaging

## Security Considerations

### Privilege Escalation (Found and Fixed)

**Vulnerability**: The columns controller used `ensure_contributor` for create/update, so any member could set `min_role: "admin"` on a column — hiding it from all other members or locking themselves out.

**Fix**: `column_params` strips `min_role` from params unless `Current.user.can_administer_board?(@board)` returns true. Only admins and board creators can change column visibility thresholds.

### Defense Layers Updated

All 6 layers that previously checked `hidden_from_viewers` were updated to use role-aware filtering:

1. **Model scopes**: `Column.visible_to(user)`, `Card.visible_to(user)`
2. **User::Accessor**: `accessible_columns`, `accessible_cards`
3. **Search**: `Search::Record.for_query` filters by visible columns per role
4. **Timeline**: `User::DayTimeline#timelineable_events` excludes events for hidden cards
5. **Controllers**: `set_column` uses `visible_to(Current.user)`, public controllers use `publicly_visible`
6. **Views**: All column renders use `visible_to(Current.user)` or `publicly_visible`

### Known Deferred Items

- **Notifications**: Not filtered by column visibility — users may receive notifications about cards in columns they can't see (information leak, lower priority)
- **Triage into restricted columns**: `Cards::TriagesController` doesn't filter target column with `visible_to` — a member could triage a card into an admin-only column by knowing the UUID
- **Webhooks**: Fire for all events regardless of column min_role

## Prevention Checklist

When modifying column access control or adding new role-based features, audit:

- [ ] All column query paths use `visible_to(Current.user)` or `publicly_visible`
- [ ] Card queries go through `accessible_cards` or `Card.visible_to`
- [ ] Search results filtered by role-aware column visibility
- [ ] Timeline events filtered by role-aware column visibility
- [ ] Closed cards, postponed cards, and triage cards all filtered
- [ ] Count badges in views use filtered counts
- [ ] Public board views use `publicly_visible` (viewer-only)
- [ ] Direct URL access returns 404 for restricted resources
- [ ] Parameter changes to authorization attributes are gated to appropriate roles
- [ ] Cache invalidation covers authorization-relevant attribute changes

## Files Changed

| File | Change |
|------|--------|
| `db/migrate/..._replace_hidden_from_viewers_with_min_role.rb` | Schema migration |
| `app/models/column.rb` | `visible_to`, `publicly_visible`, `restricted?`, `MIN_ROLES` |
| `app/models/user/role.rb` | `ROLE_LEVELS`, `role_level`, `role_at_least?` |
| `app/models/user/accessor.rb` | Role-aware `accessible_columns`, `accessible_cards` |
| `app/models/card.rb` | Role-aware `visible_to` scope |
| `app/models/search/record.rb` | Role-aware search filtering |
| `app/models/user/day_timeline.rb` | Role-aware timeline filtering |
| `app/controllers/boards/columns_controller.rb` | `min_role` params, admin gate |
| `app/controllers/cards/columns_controller.rb` | Column selector filtered |
| `app/controllers/public/base_controller.rb` | `restricted?` check |
| `app/controllers/public/boards/columns_controller.rb` | `publicly_visible` scope |
| `app/views/boards/show/menu/_column_form.html.erb` | Select dropdown |
| `app/views/boards/show/_column.html.erb` | Role-specific badge |
| `app/views/public/boards/show/_columns.html.erb` | `publicly_visible` |
| `app/views/cards/display/public_preview/_columns.html.erb` | `publicly_visible` |

## Related Documentation

- [Viewer Role: Read-Only Access](viewer-role-read-only-access.md) — Foundation for the role hierarchy
- [Closed Cards Column Visibility Bypass](closed-cards-column-visibility-bypass.md) — Authorization bypass pattern to avoid
- [Plan: Per-Column Role-Based Access](../../plans/2026-02-21-feat-per-column-role-based-access-plan.md)
- [Plan: Selective Column Visibility for Viewers](../../plans/2026-02-21-feat-selective-column-visibility-for-viewers-plan.md)
- [Plan: Add Viewer Role](../../plans/2026-02-20-feat-add-viewer-role-plan.md)
