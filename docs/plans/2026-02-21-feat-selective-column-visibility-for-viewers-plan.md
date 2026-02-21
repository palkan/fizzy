---
title: Selective column visibility for viewers
type: feat
status: completed
date: 2026-02-21
---

# Selective column visibility for viewers

Board admins can mark columns as hidden from viewers. Viewers (both authenticated and public board visitors) cannot see hidden columns or any resources (cards, comments, events) associated with them.

## Acceptance Criteria

- [x] Add `hidden_from_viewers` boolean column to the `columns` table (default: `false`)
- [x] Board admins can toggle column visibility via the column menu
- [x] Viewers cannot see hidden columns in the board view
- [x] Viewers cannot access cards belonging to hidden columns (search, activity, filters, direct URL)
- [x] Public board visitors cannot see hidden columns or their cards
- [x] Contributors (owner/admin/member) see all columns regardless of the setting
- [x] Hidden columns have a visual indicator for contributors so they know the column is restricted

## Context

The viewer role was implemented on 2026-02-20 with defense-in-depth across 4 layers (model, comment gating, controller, view). Access is currently board-level only via the `accesses` table. This feature adds column-level visibility restrictions specifically for the viewer role.

Key touchpoints:
- `app/models/column.rb` — add `hidden_from_viewers` attribute and `visible_to(user)` scope
- `app/models/user/accessor.rb:7-9` — `accessible_columns` and `accessible_cards` associations flow through boards with no column-level filtering
- `app/controllers/boards/columns_controller.rb:8` — `@board.columns.sorted` renders all columns
- `app/controllers/concerns/column_scoped.rb:10` — `accessible_columns.find(params[:column_id])`
- `app/controllers/concerns/card_scoped.rb:10` — `accessible_cards.find_by!(number: params[:card_id])`
- `app/views/boards/show/_columns.html.erb:33` — `board.columns.sorted` rendered as collection
- `app/views/public/boards/show/_columns.html.erb:17` — public board renders `board.columns`
- `app/models/search/record.rb:29` — search scoped by `board_id` but not `column_id`
- `app/models/user/day_timeline.rb:72-77` — timeline events scoped by boards, not columns
- `app/models/filter.rb:21` — filter starts from `accessible_cards`

## MVP

### Migration: `add_hidden_from_viewers_to_columns.rb`

```ruby
class AddHiddenFromViewersToColumns < ActiveRecord::Migration[8.0]
  def change
    add_column :columns, :hidden_from_viewers, :boolean, default: false, null: false
  end
end
```

### Model: `app/models/column.rb`

```ruby
class Column < ApplicationRecord
  include Colored, Positioned

  belongs_to :account, default: -> { board.account }
  belongs_to :board, touch: true
  has_many :cards, dependent: :nullify

  scope :visible_to, ->(user) {
    if user&.contributor?
      all
    else
      where(hidden_from_viewers: false)
    end
  }

  after_save_commit -> { cards.touch_all }, if: -> { saved_change_to_name? || saved_change_to_color? }
  after_destroy_commit -> { board.cards.touch_all }
end
```

### Model: `app/models/column/viewer_visible.rb` (concern)

Encapsulate viewer-visibility logic used across board, card, and search scoping:

```ruby
module Column::ViewerVisible
  extend ActiveSupport::Concern

  included do
    scope :viewer_visible, -> { where(hidden_from_viewers: false) }
  end

  def hidden_from_viewers?
    hidden_from_viewers
  end
end
```

### Model: `app/models/user/accessor.rb`

The `accessible_columns` and `accessible_cards` associations need to respect column visibility for viewers. Two approaches:

**Option A — Override accessor methods** (simpler, query at call site):
```ruby
def accessible_columns
  if contributor?
    super
  else
    super.where(columns: { hidden_from_viewers: false })
  end
end

def accessible_cards
  if contributor?
    super
  else
    super.where(column_id: [nil, *accessible_columns.select(:id)])
    # nil column_id = triage cards (always visible)
  end
end
```

**Option B — Scope at each call site**: Keep associations unchanged, apply `.visible_to(Current.user)` at every query site. More explicit, more places to update.

Recommendation: Option A centralizes the logic and reduces the surface area for bugs. Every existing call to `accessible_cards` and `accessible_columns` automatically gets the filtering.

### Controller: `app/controllers/boards/columns_controller.rb`

```ruby
def index
  @columns = @board.columns.visible_to(Current.user).sorted
  fresh_when etag: @columns
end

def column_params
  params.expect(column: [ :name, :color, :hidden_from_viewers ])
end
```

The `update` action already has `ensure_contributor`, so only contributors can toggle the setting.

### View: `app/views/boards/show/_columns.html.erb`

```erb
<%= render partial: "boards/show/column",
    collection: board.columns.visible_to(Current.user).sorted,
    cached: ->(column){ [ column, column.leftmost?, column.rightmost? ] } %>
```

### View: `app/views/public/boards/show/_columns.html.erb`

```erb
<%= render partial: "public/boards/show/column",
    collection: board.columns.viewer_visible,
    cached: true %>
```

### View: Column menu toggle — `app/views/boards/show/menu/_column_form.html.erb`

Add a checkbox to the existing column edit form:

```erb
<label class="flex gap-half align-center">
  <%= form.check_box :hidden_from_viewers %>
  <span>Hide from viewers</span>
</label>
```

### View: Hidden indicator for contributors — `app/views/boards/show/_column.html.erb`

Show a visual indicator (e.g., eye-off icon) when a column is hidden from viewers:

```erb
<% if column.hidden_from_viewers? %>
  <%= icon_tag "eye-off", class: "translucent", title: "Hidden from viewers" %>
<% end %>
```

### Search: `app/models/search/record.rb`

The `for_query` scope filters by `board_id` but not column. For viewers, exclude cards in hidden columns:

```ruby
scope :for_query, ->(query, user:) do
  query = Search::Query.wrap(query)

  if query.valid? && user.board_ids.any?
    result = matching(query.to_s, user.account_id)
      .where(account_id: user.account_id, board_id: user.board_ids)

    unless user.contributor?
      hidden_column_ids = Column.where(board_id: user.board_ids, hidden_from_viewers: true).select(:id)
      result = result.where.not(card_id: Card.where(column_id: hidden_column_ids).select(:id))
    end

    result
  else
    none
  end
end
```

### Timeline: `app/models/user/day_timeline.rb`

Filter timeline events to exclude cards in hidden columns for viewers:

```ruby
def timelineable_events
  events = Event
    .preloaded
    .where(board: boards)
    .where(action: TIMELINEABLE_ACTIONS)

  unless user.contributor?
    hidden_column_ids = Column.where(board_id: boards, hidden_from_viewers: true).select(:id)
    events = events.where.not(card_id: Card.where(column_id: hidden_column_ids).select(:id))
  end

  events
end
```

### Filter: `app/models/filter.rb`

Already starts from `creator.accessible_cards` (line 21). If Option A is implemented in `User::Accessor`, this is handled automatically — the `accessible_cards` association already filters out cards in hidden columns for viewers.

### Tests

Key test scenarios to add:

- **Model tests**: `Column#visible_to` scope returns correct columns for viewers vs contributors
- **Controller tests**: Viewer cannot see hidden columns via `Boards::ColumnsController#index`
- **Controller tests**: Viewer gets 404 when accessing a card in a hidden column directly
- **Controller tests**: Viewer search results exclude cards in hidden columns
- **System tests**: Board admin toggles column visibility, viewer sees/doesn't see column
- **Public board tests**: Hidden columns not rendered on published board page

## References

- Viewer role implementation: `docs/solutions/authorization/viewer-role-read-only-access.md`
- Access model: `app/models/access.rb`
- Board accessible concern: `app/models/board/accessible.rb`
- User role definitions: `app/models/user/role.rb`
- Existing viewer auth tests: `test/controllers/viewer_authorization_test.rb`
