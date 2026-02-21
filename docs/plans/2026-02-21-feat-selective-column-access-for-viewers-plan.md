---
title: Selective Column Access for Viewers
type: feat
status: completed
date: 2026-02-21
---

# Selective Column Access for Viewers

Board admins can mark columns as not available to viewers. Viewers cannot see restricted columns or any resources (cards, comments, etc.) associated with them.

## Acceptance Criteria

- [x] Add `viewer_restricted` boolean column to `columns` table (default: `false`)
- [x] Board admins can toggle column restriction via column menu (`boards/show/menu/_column.html.erb`)
- [x] Viewers do not see restricted columns on the board view
- [x] Viewers get 404 when accessing a card in a restricted column (direct URL)
- [x] Viewers get 404 when accessing a restricted column's maximized view
- [x] All card subresources (comments, reactions, steps, etc.) in restricted columns return 404 for viewers (automatic via `CardScoped`)
- [x] Filter results (`Filter#cards`) exclude cards in restricted columns for viewers
- [x] Search results exclude cards in restricted columns for viewers
- [x] Public boards hide restricted columns and their cards
- [x] System pseudo-columns (triage/Maybe?, Not Now, Closed) are unaffected — always visible
- [x] Non-viewer users (members, admins, owners) see all columns regardless of restriction

## Context

**Current state**: All columns are visible to anyone who can see the board. Viewer restrictions are enforced entirely at the policy layer via `not_viewer?` checks. Columns have no access controls.

**Key files**:
- `app/models/column.rb` — Column model (add `viewer_restricted` attr)
- `app/policies/column_policy.rb:8` — `show?` delegates to board; needs viewer+restriction check
- `app/policies/card_policy.rb:14` — `show?` delegates to board; needs viewer+restricted column check
- `app/policies/card_policy.rb:4` — `relation_scope` needs viewer filtering for restricted columns
- `app/controllers/boards/columns_controller.rb:52` — `column_params` needs `viewer_restricted`
- `app/views/boards/show/_columns.html.erb:33` — renders `board.columns.sorted`; needs filtering for viewers
- `app/views/boards/show/menu/_column.html.erb` — column menu; add restriction toggle
- `app/views/boards/show/menu/_column_form.html.erb` — column form; add checkbox
- `app/models/search/record.rb:25` — `for_query` scope filters by `board_id`; needs column restriction join for viewers
- `app/controllers/searches_controller.rb:7` — numeric ID fast-path uses `accessible_cards`; needs filtering
- `app/controllers/public/boards/columns_controller.rb:13` — `set_column` needs restriction check
- `app/controllers/public/boards_controller.rb` — public board view needs column filtering

## MVP

### Migration

```ruby
# db/migrate/XXXXXX_add_viewer_restricted_to_columns.rb
class AddViewerRestrictedToColumns < ActiveRecord::Migration[8.0]
  def change
    add_column :columns, :viewer_restricted, :boolean, default: false, null: false
  end
end
```

### ColumnPolicy

```ruby
# app/policies/column_policy.rb
class ColumnPolicy < ApplicationPolicy
  authorize :board, optional: true

  def create?
    allowed_to?(:manage?, board)
  end

  def show?
    if viewer? && record.viewer_restricted?
      false
    else
      allowed_to?(:show?, record.board)
    end
  end

  def manage?
    allowed_to?(:manage?, record.board)
  end
end
```

### CardPolicy

```ruby
# app/policies/card_policy.rb
class CardPolicy < ApplicationPolicy
  authorize :board, optional: true

  relation_scope do |scope|
    base = scope.left_joins(board: :accesses).where(boards: { all_access: true }).or(
      scope.left_joins(board: :accesses).where(accesses: { user_id: user.id })
    ).distinct

    if viewer?
      base.left_joins(:column).where(columns: { viewer_restricted: [false, nil] }).or(
        base.left_joins(:column).where(column_id: nil)
      )
    else
      base
    end
  end

  def create?
    check?(:not_viewer?) && allowed_to?(:show?, board)
  end

  def show?
    if viewer? && record.column&.viewer_restricted?
      false
    else
      allowed_to?(:show?, record.board)
    end
  end

  def manage?
    check?(:not_viewer?) && allowed_to?(:show?, record.board)
  end

  def destroy?
    allowed_to?(:manage?) &&
      check?(:can_administer?)
  end

  def can_administer?
    admin? || record.creator == user
  end
end
```

### Board view — filter columns for viewers

```erb
<%# app/views/boards/show/_columns.html.erb, line 33 %>
<%# Change: board.columns.sorted → columns_for_board(board) or inline policy check %>
<%= render partial: "boards/show/column",
    collection: board.columns.sorted.reject { |c| current_user.viewer? && c.viewer_restricted? },
    cached: ->(column){ [ column, column.leftmost?, column.rightmost? ] } %>
```

Note: prefer moving this to a helper or using `authorized_scope` in the controller for the column collection if the inline check feels too heavy for the view.

### Column menu — add restriction toggle

```erb
<%# app/views/boards/show/menu/_column.html.erb — add before the delete item %>
<% if allowed_to?(:manage?, column) %>
  <li class="popup__item">
    <%= button_to board_column_path(column.board, column),
          method: :patch,
          params: { column: { viewer_restricted: !column.viewer_restricted? } },
          class: "popup__btn btn",
          form_class: "display-contents" do %>
      <%= icon_tag column.viewer_restricted? ? "eye" : "eye-off" %>
      <span><%= column.viewer_restricted? ? "Show to viewers" : "Hide from viewers" %></span>
    <% end %>
  </li>
<% end %>
```

### Column params — permit new attribute

```ruby
# app/controllers/boards/columns_controller.rb:52
def column_params
  params.expect(column: [ :name, :color, :viewer_restricted ])
end
```

### Search — filter restricted columns for viewers

```ruby
# app/models/search/record.rb — update for_query scope
scope :for_query, ->(query, user:) do
  query = Search::Query.wrap(query)

  if query.valid? && user.board_ids.any?
    result = matching(query.to_s, user.account_id).where(account_id: user.account_id, board_id: user.board_ids)
    if user.viewer?
      result.joins("INNER JOIN cards ON cards.id = #{table_name}.card_id")
            .joins("LEFT JOIN columns ON columns.id = cards.column_id")
            .where("columns.viewer_restricted = ? OR cards.column_id IS NULL", false)
    else
      result
    end
  else
    none
  end
end
```

### Search controller — numeric ID fast-path

```ruby
# app/controllers/searches_controller.rb:7
def show
  if card = Current.user.accessible_cards.find_by_id(params[:q])
    if Current.user.viewer? && card.column&.viewer_restricted?
      set_page_and_extract_portion_from Current.user.search(params[:q])
    else
      @card = card
    end
  else
    set_page_and_extract_portion_from Current.user.search(params[:q])
  end
  @recent_search_queries = Current.user.search_queries.order(updated_at: :desc).limit(10)
end
```

### Public boards — filter restricted columns

```ruby
# app/controllers/public/boards/columns_controller.rb
def set_column
  @column = @board.columns.where(viewer_restricted: false).find(params[:id])
end
```

```erb
<%# Public board column rendering — filter restricted columns %>
board.columns.sorted.where(viewer_restricted: false)
```

### Test files

- `test/policies/column_policy_test.rb` — viewer cannot `show?` restricted column; admin can
- `test/policies/card_policy_test.rb` — viewer cannot `show?` card in restricted column; triage card (nil column) still visible; non-viewer unaffected
- `test/controllers/boards/columns_controller_test.rb` — viewer cannot access restricted column show; admin can toggle `viewer_restricted`
- `test/controllers/searches_controller_test.rb` — viewer search excludes restricted column cards; numeric ID fast-path excluded
- `test/controllers/public/boards/columns_controller_test.rb` — restricted columns return 404 on public boards

## Edge Cases

- **Closed cards**: Retain `column_id` — a closed card in a restricted column is hidden from viewers in the Closed panel. This is consistent: the restriction follows the column assignment.
- **Postponed cards**: `column_id` is set to nil when postponed — viewer can see postponed cards in the Not Now panel even if they originated from a restricted column.
- **Notifications**: Existing notifications for cards that move into restricted columns will produce 404 when clicked. Acceptable for MVP; notification cleanup can be added later.
- **Pins**: Pinned cards in restricted columns will show in the pin tray but 404 on click. Same as notifications — acceptable for MVP.

## References

- `docs/solutions/security-issues/authorization-gaps-viewer-role-action-policy.md` — viewer role authorization gaps checklist
- `docs/solutions/action-policy-authorization-patterns.md` — policy patterns (use `check?`, `allowed_to?`, `relation_scope`)
- `docs/solutions/action-policy-migration-pitfalls.md` — `.or()` structural compatibility with `left_joins` + `.distinct`
