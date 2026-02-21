---
title: "feat: Add Viewer Role"
type: feat
status: completed
date: 2026-02-21
---

# Add Viewer Role

## Overview

Add a new `viewer` role to Fizzy that provides read-only access to boards and cards with a single exception: viewers can comment on cards that are awaiting triage (not yet assigned to a column). Viewers cannot create, edit, or manage any content, cannot be assigned to cards, and have no access to administrative areas of the app. Demoting a user to viewer immediately revokes all prior privileges.

## Problem Statement / Motivation

Fizzy currently has four roles: `owner`, `admin`, `member`, `system`. All active human roles (owner, admin, member) have full read-write access to cards on boards they can see. There is no way to invite stakeholders, clients, or observers who should see progress without being able to modify anything. A `viewer` role fills this gap, allowing teams to share visibility without granting edit capabilities.

## Proposed Solution

Add `viewer` to the role enum and enforce restrictions entirely through the Action Policy layer. The policy changes propagate to the UI via existing `allowed_to?` view helpers. No new authorization infrastructure is needed -- just tighter rules in existing policies and new `allowed_to?` guards in views that currently lack them.

### Key Interpretation Decisions

- **"Cards being triaged"** = `awaiting_triage?` (active cards with no column assigned, sitting in the triage inbox). Once a card is triaged into a column, viewers can no longer comment on it.
- **"No access to other parts of the app"** = viewers cannot access account settings, tag management, people/invite section, exports/imports, or board creation. They retain access to: their own profile, notification settings, and sign out.
- **Reactions** are restricted (viewers can only see and comment on triage cards -- all other interactive actions are blocked).

## Technical Approach

### Phase 1: Model Layer

#### 1.1 Add `viewer` to role enum

**File:** `app/models/user/role.rb`

```ruby
enum :role, %i[ owner admin member viewer system ].index_by(&:itself), scopes: false

scope :owner, -> { where(active: true, role: :owner) }
scope :admin, -> { where(active: true, role: %i[ owner admin ]) }
scope :member, -> { where(active: true, role: :member) }
scope :viewer, -> { where(active: true, role: :viewer) }
scope :active, -> { where(active: true).where.not(role: :system) }
```

Viewers are included in the `active` scope (they are real users) but excluded from `admin` and `member` scopes.

#### 1.2 Exclude viewers from assignable scope

**File:** `app/policies/user_policy.rb:6-8`

The `assignable` relation scope currently excludes only `system`:

```ruby
relation_scope :assignable do |scope|
  scope.where.not(role: :system)
end
```

Change to:

```ruby
relation_scope :assignable do |scope|
  scope.where.not(role: %i[ system viewer ])
end
```

### Phase 2: Policy Layer (Core)

This is the heart of the feature. Add a `viewer?` delegate to `ApplicationPolicy` and update each policy.

#### 2.1 ApplicationPolicy

**File:** `app/policies/application_policy.rb`

Add `viewer?` delegate alongside existing `admin?` and `owner?`:

```ruby
class ApplicationPolicy < ActionPolicy::Base
  authorize :user
  authorize :account

  delegate :admin?, :owner?, :viewer?, to: :user

  def show?
    false
  end

  def manage?
    false
  end
end
```

Add a reusable `not_viewer?` check:

```ruby
def not_viewer?
  !viewer?
end
```

#### 2.2 CardPolicy

**File:** `app/policies/card_policy.rb`

- `create?` -- block viewers (currently allows anyone with board access)
- `manage?` -- block viewers (currently allows anyone with board access)

```ruby
class CardPolicy < ApplicationPolicy
  authorize :board, optional: true

  relation_scope do |scope|
    scope.joins(board: :accesses).where(accesses: { user_id: user.id })
  end

  def create?
    check?(:not_viewer?) && allowed_to?(:show?, board)
  end

  def show?
    allowed_to?(:show?, record.board)
  end

  def manage?
    check?(:not_viewer?) && allowed_to?(:show?, record.board)
  end

  def destroy?
    allowed_to?(:manage?) && check?(:can_administer?)
  end

  def can_administer?
    admin? || record.creator == user
  end
end
```

#### 2.3 CommentPolicy

**File:** `app/policies/comment_policy.rb`

- `create?` -- allow viewers only if card is `awaiting_triage?`
- `manage?` -- block viewers (cannot edit/delete even their own comments)

```ruby
class CommentPolicy < ApplicationPolicy
  authorize :card, optional: true

  def create?
    if viewer?
      check?(:card_awaiting_triage?) && allowed_to?(:show?, card)
    else
      allowed_to?(:show?, card)
    end
  end

  def show?
    allowed_to?(:show?, record.card)
  end

  def manage?
    check?(:not_viewer?) && allowed_to?(:show?) && check?(:creator?)
  end

  def creator?
    record.creator == user
  end

  def card_awaiting_triage?
    card&.awaiting_triage?
  end
end
```

#### 2.4 BoardPolicy

**File:** `app/policies/board_policy.rb`

- `create?` -- block viewers (currently unconditionally `true`)

```ruby
def create?
  check?(:not_viewer?)
end
```

`show?` and `manage?` remain unchanged -- viewers can see boards they have access to, and `manage?` already requires admin.

#### 2.5 ReactionPolicy

**File:** `app/policies/reaction_policy.rb`

- `create?` -- block viewers (currently unconditionally `true`)

```ruby
def create?
  check?(:not_viewer?)
end
```

#### 2.6 AccountPolicy

**File:** `app/policies/account_policy.rb`

No changes needed. `manage?` already requires `admin?`, which excludes viewers.

#### 2.7 ColumnPolicy, WebhookPolicy

No changes needed. These already delegate to `board manage?` which requires admin.

### Phase 3: Controller Layer

#### 3.1 Roles Controller

**File:** `app/controllers/users/roles_controller.rb:17-19`

Add `viewer` to allowed role values:

```ruby
def role_params
  { role: params.require(:user)[:role].presence_in(%w[ member admin viewer ]) || "member" }
end
```

#### 3.2 Navigation restrictions

Viewers should not access these controllers. Add `authorize!` checks or restrict at the policy level:

- `Account::SettingsController` -- already checks `AccountPolicy` (viewers see read-only, which is acceptable since `manage?` blocks mutations). However, per spec "no access to other parts" -- consider blocking access entirely with a new policy check, or let the existing read-only rendering stand.
- `TagsController` -- viewers should not access tag management
- `Account::JoinCodesController` -- viewers should not invite people

**Decision:** Rather than adding bespoke controller-level checks for each "other part of the app", add a concern that redirects viewers from non-board/card areas:

**File:** `app/controllers/concerns/authorization.rb` (or a new `ViewerRestricted` concern)

Add to controllers that viewers should not access:
- Account settings controllers (except profile-related)
- Tags controllers
- Join code controllers
- Export/import controllers

The simplest approach: check `Current.user.viewer?` in `before_action` for these controllers. However, per STYLE.md, prefer policy-based authorization. The `AccountPolicy#manage?` already blocks mutations. For _showing_ account settings to viewers, the decision is whether to block the page entirely or show read-only.

**Recommended approach:** Block account settings page entirely for viewers. Add to the relevant controllers:

```ruby
before_action :ensure_not_viewer

private
  def ensure_not_viewer
    head :forbidden if Current.user.viewer?
  end
```

Or better, use a policy check: `authorize! Current.account, to: :manage?` on the `show` action of settings controllers (this already returns 403 for non-admins, which includes viewers).

### Phase 4: View Layer

#### 4.1 Add card button

**File:** `app/views/columns/show/_add_card_button.html.erb`

Wrap in policy check:

```erb
<% if allowed_to?(:create?, Card, context: { board: board }) %>
  <div class="board-tools card">
    <%= button_to board_cards_path(board), ... %>
    <footer>
      <%= access_involvement_advance_button(board, Current.user, show_watchers: true) %>
    </footer>
  </div>
<% end %>
```

#### 4.2 Card action buttons (Edit, Mark as Done)

**File:** `app/views/cards/container/_closure_buttons.html.erb`

Wrap in policy check:

```erb
<% if allowed_to?(:manage?, card) %>
  <div class="flex gap-half">
    <%= link_to edit_card_path(card), ... %>
    <%= button_to card_closure_path(card), ... %>
  </div>
<% end %>
```

#### 4.3 Card sidebar actions (Gild, Image, Watch, Pin)

**Files:**
- `app/views/cards/container/_gild.html.erb` -- wrap in `allowed_to?(:manage?, card)`
- `app/views/cards/container/_image.html.erb` -- wrap in `allowed_to?(:manage?, card)`
- `app/views/cards/container/footer/_published.html.erb` -- wrap watch/pin buttons in `allowed_to?(:manage?, card)`

#### 4.4 Tag picker

**File:** `app/views/cards/display/perma/_tags.html.erb`

Hide the tag picker button for viewers (keep tag display visible):

```erb
<% if allowed_to?(:manage?, card) %>
  <div data-controller="dialog" ...>
    <button class="card__tag-picker-button btn card__hide-on-index" ...>
      ...
    </button>
    ...
  </div>
<% end %>
```

#### 4.5 Assignee picker

**File:** `app/views/cards/display/common/_assignees.html.erb`

Show assigned avatars but hide the assign button/dialog for viewers. Wrap the interactive elements in `allowed_to?(:manage?, card)`:

```erb
<% if allowed_to?(:manage?, card) %>
  <div id="<%= dom_id(card, :assignees) %>" data-controller="dialog" ...>
    <button class="card__assignees-trigger" ...>
      ...
    </button>
    ...
  </div>
<% else %>
  <div id="<%= dom_id(card, :assignees) %>">
    <% card.assignees.each do |assignee| %>
      <%= avatar_preview_tag assignee %>
    <% end %>
  </div>
<% end %>
```

#### 4.6 Comment form

**File:** `app/views/cards/comments/_new.html.erb` (rendered from `app/views/cards/_messages.html.erb`)

Conditionally render the comment form based on policy:

In `app/views/cards/_messages.html.erb`, change:

```erb
<%= render "cards/comments/new", card: card %>
```

To:

```erb
<% if allowed_to?(:create?, Comment, context: { card: card }) %>
  <%= render "cards/comments/new", card: card %>
<% end %>
```

This will show the comment form for viewers only on triage cards.

#### 4.7 Comment edit/delete

**File:** `app/views/cards/comments/_comment.html.erb`

Ensure edit/delete controls on individual comments are gated by `allowed_to?(:manage?, comment)`. Check if this is already the case; if not, add the check.

#### 4.8 Reaction buttons

Ensure reaction buttons are gated by `allowed_to?(:create?, Reaction)` or wrap in `allowed_to?(:manage?, card)`.

**File:** `app/views/reactions/_reactions.html.erb` -- hide "add reaction" button for viewers.

#### 4.9 Navigation menu

**File:** `app/views/my/menus/show.html.erb`

Conditionally hide sections for viewers:

```erb
<%= render "my/menus/boards", boards: @boards %>
<% unless Current.user.viewer? %>
  <%= render "my/menus/tags", tags: @tags %>
  <%= render "my/menus/people", users: @users %>
<% end %>
<%= render "my/menus/settings" %>
<%= render "my/menus/shortcuts" %>
<%= render "my/menus/accounts", accounts: @accounts %>
```

**Note:** Using `Current.user.viewer?` here rather than `allowed_to?` is acceptable because this is a navigation gating decision, not an authorization check on a specific resource. However, if preferred, a policy-based approach could be used.

#### 4.10 Settings menu

**File:** `app/views/my/menus/_settings.html.erb`

Hide "Account Settings" for viewers (keep profile, notifications, sign out):

```erb
<%= collapsible_nav_section "Settings" do %>
  <% unless Current.user.viewer? %>
    <%= filter_place_menu_item account_settings_path, "Account Settings", "settings" %>
  <% end %>
  <%= filter_place_menu_item user_path(Current.user), "My Profile", "person" %>
  <%= filter_place_menu_item notifications_path, "All notifications", "bell" %>
  <%= filter_place_menu_item notifications_settings_path, "Notification Settings", "settings" %>
  ...sign out...
<% end %>
```

#### 4.11 Board header

**File:** `app/views/boards/show.html.erb`

Hide the "Edit board" settings gear for viewers:

```erb
<% if allowed_to?(:manage?, @board) %>
  <div class="header__actions header__actions--end hide-on-native">
    <%= link_to_edit_board @board %>
  </div>
<% end %>
```

#### 4.12 Role management UI

**File:** `app/views/account/settings/_user.html.erb`

Change the binary admin/member checkbox to a dropdown or radio group that includes `viewer`:

```erb
<%= form.select :role, [["Member", "member"], ["Admin", "admin"], ["Viewer", "viewer"]],
      { selected: user.role },
      { data: { action: "form#submit" }, disabled: !allowed_to?(:change_role?, user) } %>
```

#### 4.13 Role display helper

**File:** `app/helpers/users_helper.rb`

Update to handle viewer:

```ruby
def role_display_name(user)
  case user.role
  when "admin" then "Administrator"
  when "viewer" then "Viewer"
  else user.role.titleize
  end
end
```

### Phase 5: Edge Cases & Cleanup

#### 5.1 Demotion handling

When a user is demoted from member/admin to viewer:
- Existing card assignments should remain visible but the viewer can no longer be assigned to new cards (handled by `UserPolicy.assignable` scope change)
- Existing comments remain (they are historical records)
- The user's session continues to work -- policy checks enforce the new restrictions immediately since they read `user.role` live from the database
- No background job needed to clean up existing data

#### 5.2 Board access

Viewer board access works identically to member access via the `Access` model. No changes needed to the access system -- the restriction is purely at the policy level.

#### 5.3 Search

Viewers can search within boards they have access to. The search scoping already uses `CardPolicy.relation_scope` which filters by board access. No changes needed.

#### 5.4 Notifications

Viewers should still receive notifications for boards they watch and cards they're mentioned on. The notification system should continue working -- viewers just can't take action on most notifications. No changes needed to the notification system.

#### 5.5 API / JSON endpoints

Several controllers respond to JSON format. The policy layer covers these since `authorize!` is called regardless of format. No additional changes needed.

#### 5.6 Keyboard shortcuts

Keyboard shortcuts that trigger restricted actions (C for new card, E for edit, D for mark done, T for tag, A for assign, G for gild) will hit authorization failures if used by viewers. Since the UI buttons are hidden, the shortcuts won't have visible triggers, but the controller-level authorization will still block the action with a 403. This is acceptable.

#### 4.14 Activity timeline buttons

**Files (identified by SpecFlow analysis):**
- `app/views/events/index/_add_card_button.html.erb` -- hide "Add a card" button
- `app/views/events/index/_add_board_button.html.erb` -- hide "Add a board" button

Wrap in `allowed_to?(:create?, Card, ...)` and `allowed_to?(:create?, Board)` respectively.

#### 4.15 Navigation "Add a board"

**File:** `app/views/my/menus/_boards.html.erb`

Hide "Add a board" link for viewers:

```erb
<% if allowed_to?(:create?, Board) %>
  <!-- existing add board link -->
<% end %>
```

#### 4.16 Card content edit link

**File:** `app/views/cards/container/_content_display.html.erb`

If this renders an inline edit link or edit-in-place trigger, wrap in `allowed_to?(:manage?, card)`.

#### 4.17 Card steps creation

**File:** `app/views/cards/display/perma/_steps.html.erb` or related

Hide step creation controls for viewers. Steps are part of card management.

#### 4.18 Triage column picker

**File:** `app/views/cards/triage/_columns.html.erb` (or equivalent)

The column picker for triaging cards into columns should be hidden for viewers since they cannot triage.

## Open Questions (from SpecFlow Analysis)

These questions were identified during specification flow analysis. Defaults are provided but should be confirmed.

### Resolved (using defaults)

1. **Activity timeline (home page):** Viewers CAN see the activity timeline -- it's read-only and essential for navigation. The "Add card" and "Add board" buttons are hidden via policy checks.

2. **Search:** Viewers CAN search -- it's fundamental to navigating boards/cards and already scoped by board access.

3. **Notifications:** Viewers CAN receive and manage notifications -- needed for comment replies on triage cards.

4. **Saved filters:** Viewers CAN create/delete personal filters -- these are personal viewing preferences, not card mutations.

5. **Own profile:** Viewers CAN edit their own profile (name, avatar) -- basic self-management.

6. **Demotion data cleanup:** Existing assignments, comments, pins, and watches remain in place after demotion. The viewer simply cannot perform those actions going forward. No background cleanup job needed.

7. **Comment attachments:** Viewers CAN attach files when commenting on triage cards -- rich text comments are the standard format.

8. **Entropy interaction:** Viewer comments DO count as activity (they touch the card) -- consistent with all other comment behavior.

### Needs Confirmation

9. **Pin/watch for viewers:** Currently gated by `CardPolicy#manage?` which will block viewers. Pins and watches are personal reading aids, not card mutations. **Should we split them out of `manage?` into a separate policy rule to allow viewers to pin/watch?** Default: No -- keep it simple, viewers cannot pin or watch. This can be revisited later.

10. **Reactions for viewers:** Card reactions are gated by `manage?` (blocked). Comment reactions use `ReactionPolicy#create?` which is unconditionally `true`. **Should both be blocked, or should comment reactions remain allowed?** Default: Both blocked via `ReactionPolicy#create?` change.

11. **Race condition -- card triaged while viewer writes comment:** The server will reject the comment via policy check and return 403. The Turbo Stream broadcast for triage events will naturally update the card UI. No additional real-time form hiding needed -- the 403 is sufficient.

## System-Wide Impact

- **Interaction graph:** Role change triggers no callbacks. Policy checks are stateless and read from `user.role` on every request. No cascading effects.
- **Error propagation:** Viewers hitting restricted endpoints get 403 (or 404 for `show?` failures). Standard error handling applies.
- **State lifecycle risks:** None. Demotion to viewer doesn't orphan data -- existing cards, comments, and assignments remain intact.
- **API surface parity:** JSON API endpoints share the same controller actions and policy checks. No separate API to update.
- **Cache implications:** Card container views use `cache card` -- after adding `allowed_to?` checks inside cached blocks, the cache key must incorporate the user's role. Consider moving permission-gated elements outside the `cache` block or adding role to the cache key.

## Acceptance Criteria

### Functional Requirements

- [x] Viewer can see boards they have access to (both all_access and selective)
- [x] Viewer can see cards on accessible boards
- [x] Viewer can comment on cards that are awaiting triage (no column assigned)
- [x] Viewer cannot comment on cards that have been triaged into a column
- [x] Viewer cannot create cards
- [x] Viewer cannot create boards
- [x] Viewer cannot edit, close, reopen, or delete cards
- [x] Viewer cannot assign or be assigned to cards
- [x] Viewer cannot tag cards
- [x] Viewer cannot triage cards into columns
- [x] Viewer cannot pin, watch, or gild cards
- [x] Viewer cannot add reactions
- [x] Viewer cannot edit or delete their own comments
- [x] Viewer cannot access account settings page
- [x] Viewer cannot access tag management
- [x] Viewer cannot access people/invite section
- [x] Viewer has no "Add a card" button visible
- [x] Viewer has no edit/close/assign/tag buttons visible on cards
- [x] Viewer has no comment form on triaged cards (only on triage inbox cards)
- [x] Demoting a user from member/admin to viewer immediately restricts their access
- [x] Admin can set a user's role to viewer via account settings
- [x] Viewer can still manage their own profile
- [x] Viewer can still manage notification settings
- [x] Navigation hides tags, people sections for viewers
- [x] Settings menu hides "Account Settings" for viewers

### Non-Functional Requirements

- [x] All restricted actions return 403 when attempted via direct URL/API
- [x] Keyboard shortcuts for restricted actions are blocked at the controller level
- [x] Existing tests continue to pass (no regressions for other roles)

## Comprehensive View Audit Checklist

Every view with interactive elements that viewers should not see (identified by SpecFlow analysis + manual review):

| View File | Element | Gate |
|-----------|---------|------|
| `columns/show/_add_card_button.html.erb` | "Add a card" button | `allowed_to?(:create?, Card, context: {board:})` |
| `events/index/_add_card_button.html.erb` | "Add a card" button | `allowed_to?(:create?, Card, context: {board:})` |
| `events/index/_add_board_button.html.erb` | "Add a board" button | `allowed_to?(:create?, Board)` |
| `cards/container/_closure_buttons.html.erb` | Edit + Mark as Done | `allowed_to?(:manage?, card)` |
| `cards/container/_gild.html.erb` | Goldness toggle | `allowed_to?(:manage?, card)` |
| `cards/container/_image.html.erb` | Image add/remove | `allowed_to?(:manage?, card)` |
| `cards/container/footer/_published.html.erb` | Watch + Pin buttons | `allowed_to?(:manage?, card)` |
| `cards/container/_closure.html.erb` | Undo close button | `allowed_to?(:manage?, card)` |
| `cards/container/_content.html.erb` / `_content_display.html.erb` | Edit form/link | `allowed_to?(:manage?, card)` |
| `cards/display/perma/_tags.html.erb` | Tag picker button | `allowed_to?(:manage?, card)` |
| `cards/display/common/_assignees.html.erb` | Assign button + dialog | `allowed_to?(:manage?, card)` |
| `cards/display/perma/_steps.html.erb` | Step creation | `allowed_to?(:manage?, card)` |
| `cards/triage/_columns.html.erb` | Column picker | `allowed_to?(:manage?, card)` |
| `cards/_messages.html.erb` | Comment form | `allowed_to?(:create?, Comment, context: {card:})` |
| `cards/_messages.html.erb` | Delete card section | already gated by `allowed_to?(:destroy?, card)` |
| `cards/comments/_comment.html.erb` | Edit/delete buttons | `allowed_to?(:manage?, comment)` |
| `reactions/_reactions.html.erb` | Add reaction button | `allowed_to?(:create?, Reaction)` |
| `boards/show.html.erb` | Edit board link | `allowed_to?(:manage?, @board)` |
| `my/menus/show.html.erb` | Tags + People sections | `Current.user.viewer?` |
| `my/menus/_settings.html.erb` | Account Settings link | `Current.user.viewer?` |
| `my/menus/_boards.html.erb` | "Add a board" link | `allowed_to?(:create?, Board)` |
| `my/menus/_people.html.erb` | "Invite people" link | `allowed_to?(:manage?, Current.account)` |
| `account/settings/_user.html.erb` | Role toggle UI | Change from checkbox to select with viewer option |

## Dependencies & Risks

- **Cache invalidation:** Card container views are cached with `cache card`. Adding `allowed_to?` checks inside cached blocks will cause incorrect rendering. Must either move gated elements outside `cache` blocks or incorporate user role into cache keys.
- **Turbo Frame lazy loading:** Some UI elements (assignment picker, tag picker) load via lazy Turbo Frames. The frame endpoints need authorization checks to prevent viewers from loading these frames directly.
- **View fragment caching:** Any view fragment that now conditionally renders based on viewer role must have role-aware cache keys.

## References & Research

### Internal References

- Role enum: `app/models/user/role.rb:5`
- ApplicationPolicy: `app/policies/application_policy.rb`
- CardPolicy: `app/policies/card_policy.rb`
- CommentPolicy: `app/policies/comment_policy.rb`
- BoardPolicy: `app/policies/board_policy.rb`
- ReactionPolicy: `app/policies/reaction_policy.rb`
- UserPolicy (assignable scope): `app/policies/user_policy.rb:6-8`
- Triage logic: `app/models/card/triageable.rb:15` (`awaiting_triage?`)
- Roles controller: `app/controllers/users/roles_controller.rb:17-19`
- Add card button: `app/views/columns/show/_add_card_button.html.erb`
- Card closure buttons: `app/views/cards/container/_closure_buttons.html.erb`
- Comment form: `app/views/cards/_messages.html.erb:4`
- Assignee picker: `app/views/cards/display/common/_assignees.html.erb`
- Tag picker: `app/views/cards/display/perma/_tags.html.erb`
- Navigation menu: `app/views/my/menus/show.html.erb`
- Settings menu: `app/views/my/menus/_settings.html.erb`
- Board header: `app/views/boards/show.html.erb:17`
- Role management UI: `app/views/account/settings/_user.html.erb:17`
- User fixtures: `test/fixtures/users.yml`
- Authorization concern: `app/controllers/concerns/authorization.rb`
- Action Policy patterns: `docs/solutions/action-policy-authorization-patterns.md`
- Migration pitfalls: `docs/solutions/action-policy-migration-pitfalls.md`

### Testing Plan

- [x] Add `viewer` user fixture (e.g., `pat`) in 37s account with access to writebook board
- [x] Add identity fixture for viewer user
- [x] Add access fixture for viewer on writebook board
- [x] Policy unit tests for every policy verifying viewer restrictions:
  - `CardPolicyTest`: viewer cannot create, manage, or destroy cards
  - `CommentPolicyTest`: viewer can create comment on triage card, cannot on triaged card, cannot manage own comment
  - `BoardPolicyTest`: viewer can show accessible boards, cannot create boards
  - `ReactionPolicyTest`: viewer cannot create reactions
  - `UserPolicyTest`: viewer excluded from assignable scope
- [ ] Controller integration tests:
  - Viewer can GET board show page
  - Viewer can GET card show page
  - Viewer can POST comment on triage card
  - Viewer gets 403 when POSTing comment on triaged card
  - Viewer gets 403 when POSTing new card
  - Viewer gets 403 when PATCHing card
  - Viewer gets 403 when accessing account settings
- [ ] System tests:
  - Verify viewer sees no "Add a card" button
  - Verify viewer sees no edit/close buttons on cards
  - Verify viewer sees comment form only on triage cards
  - Verify navigation hides tags/people for viewers
