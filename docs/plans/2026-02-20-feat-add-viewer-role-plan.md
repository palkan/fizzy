---
title: Add Viewer Role
type: feat
status: completed
date: 2026-02-20
---

# Add Viewer Role

## Overview

Add a new `viewer` role to Fizzy that provides read-only access to boards and cards, with the sole write capability of commenting on cards that are awaiting triage. Viewers cannot create or modify cards, boards, assignments, or access any administrative parts of the app. Demoting a user to viewer immediately revokes all prior privileges including creator-based permissions.

## Problem Statement / Motivation

Teams need a way to give stakeholders, clients, or observers visibility into project boards without granting them the ability to modify work items. Currently the lowest non-system role is `member`, which has full create/edit/delete access to cards, boards, comments, and assignments. There is no read-only option.

## Proposed Solution

Add `viewer` as a fifth role in the existing string-backed enum. Follow the established `ensure_*` guard pattern with a new centralized `ensure_contributor` check applied broadly to mutating endpoints, with explicit opt-outs for viewer-allowed actions.

## Technical Approach

### Phase 1: Model Layer

#### 1.1 Add viewer to role enum

**File:** `app/models/user/role.rb`

```ruby
enum :role, %i[ owner admin member viewer system ].index_by(&:itself), scopes: false
```

Update scopes:

```ruby
# Include viewer in active (they are real, active users)
scope :active, -> { where(active: true, role: %i[ owner admin member viewer ]) }

# New scope: users who can create/edit/modify content
scope :contributor, -> { where(active: true, role: %i[ owner admin member ]) }
```

Add predicate and convenience method:

```ruby
def contributor?
  owner? || admin? || member?
end
```

#### 1.2 Update permission query methods

**File:** `app/models/user/role.rb`

Override `can_administer_board?` and `can_administer_card?` to return `false` for viewers regardless of creator status:

```ruby
def can_administer_board?(board)
  contributor? && (admin? || board.creator == self)
end

def can_administer_card?(card)
  contributor? && (admin? || card.creator == self)
end
```

#### 1.3 Comment permission

**File:** `app/models/card/commentable.rb`

Add a user-aware method:

```ruby
def commentable_by?(user)
  commentable? && (user.contributor? || awaiting_triage?)
end
```

This preserves the existing `commentable?` for non-role contexts while gating viewers to triage-only commenting.

#### 1.4 Assignment exclusion

**File:** `app/models/card/assignable.rb`

In `toggle_assignment` and `assign`, reject viewer users. Also update the assignment candidate query.

**File:** `app/controllers/cards/assignments_controller.rb`

Filter the user list to exclude viewers:

```ruby
@users = @board.users.contributor.alphabetically...
```

#### 1.5 Demotion cleanup

**File:** `app/models/user/role.rb` (or a new concern `User::Demotable`)

When role changes to `viewer`, run cleanup:

- Remove all card assignments (unassign from every card)
- Delete drafted cards (unpublished work the viewer can no longer edit)

Use an `after_update_commit` callback or handle in the controller. Prefer callback for consistency:

```ruby
after_update_commit :cleanup_on_viewer_demotion, if: :viewer?

private
  def cleanup_on_viewer_demotion
    return unless role_previously_changed? && viewer?
    assignments.destroy_all
    cards.drafted.destroy_all
  end
```

### Phase 2: Authorization Layer

#### 2.1 Add centralized guard

**File:** `app/controllers/concerns/authorization.rb`

```ruby
def ensure_contributor
  head :forbidden unless Current.user.contributor?
end
```

#### 2.2 Apply guard to mutating controllers

Add `before_action :ensure_contributor` to all controllers with mutating endpoints. This is the safest approach -- block by default, then explicitly allow viewer actions.

**Controllers requiring `ensure_contributor` on all actions:**
- `CardsController` -- `new`, `create`, `edit`, `update` (destroy already has `can_administer_card?`)
- `BoardsController` -- `new`, `create` (update/destroy already have `can_administer_board?`)
- `Cards::TriagesController` -- `create`, `destroy`
- `Cards::ClosuresController` -- `create`, `destroy`
- `Cards::NotNowsController` -- `create`
- `Cards::GoldnessesController` -- `create`, `destroy`
- `Cards::AssignmentsController` -- `new`, `create`
- `Cards::SelfAssignmentsController` -- `create`
- `Cards::StepsController` -- `create`, `update`, `destroy`
- `Cards::TaggingsController` -- `create`
- `Cards::ImagesController` -- `destroy`
- `Cards::BoardsController` -- `update`
- `Cards::PublishesController` -- `create`
- `Cards::DraftsController` -- `show`, `update`
- `Boards::ColumnsController` -- `create`, `update`, `destroy`
- `Columns::RightPositionsController` -- `create`
- `Columns::LeftPositionsController` -- `create`
- All `Columns::Cards::Drops::*` controllers -- `create`

**Controllers with viewer-specific logic:**
- `Cards::CommentsController` -- `create` needs triage check for viewers; `edit`, `update`, `destroy` need viewer+triage check

#### 2.3 Comment controller special handling

**File:** `app/controllers/cards/comments_controller.rb`

Replace the blanket `ensure_card_is_commentable` with a role-aware check:

```ruby
before_action :ensure_can_comment, only: :create
before_action :ensure_can_edit_comment, only: %i[ edit update destroy ]

private
  def ensure_can_comment
    head :forbidden unless @card.commentable_by?(Current.user)
  end

  def ensure_can_edit_comment
    head :forbidden unless Current.user.contributor? || @card.awaiting_triage?
  end
```

Combined with the existing `ensure_creatorship`, viewers can only edit/delete their own comments on triage cards.

#### 2.4 Restrict "other parts of the app"

Add `ensure_contributor` to:

- `Account::SettingsController` -- all actions (not just update)
- `Account::EntropiesController` -- all actions
- `Account::JoinCodesController` -- all actions
- `BoardsController#edit` -- viewing board settings
- `Boards::PublicationsController` -- all actions
- `Boards::EntropiesController` -- all actions
- `UsersController#index`, `#show` -- user directory pages (viewers don't need these)
- `Users::RolesController` -- already admin-only, but verify
- `Webhooks*` -- already admin-only

**Allow for viewers (no guard needed):**
- `BoardsController#index`, `#show` -- viewing boards
- `CardsController#show` -- viewing cards
- `Cards::PinsController` -- personal
- `Cards::WatchesController` -- personal
- `Cards::ReadingsController` -- read tracking
- `Cards::ReactionsController` -- lightweight engagement
- `Cards::Comments::ReactionsController` -- lightweight engagement
- `FiltersController` -- personal view configuration
- `SearchesController` -- read-only, scoped to accessible cards
- `EventsController#index` -- activity timeline (read-only)
- `Notifications::*` -- personal notifications
- `My::*` -- personal settings (identity, menu)
- `My::AccessTokensController` -- restrict to read-only tokens for viewers (see Phase 4)

### Phase 3: View Layer (UI Suppression)

Introduce a helper for readability:

**File:** `app/helpers/application_helper.rb` (or existing authorization-related helper)

```ruby
def contributor?
  Current.user.contributor?
end
```

#### 3.1 Board-level UI

**File:** `app/views/boards/show.html.erb`
- Hide "Settings" link for viewers (line ~17)
- Hide "New board" link on board index (check boards index view)

**File:** `app/views/boards/edit.html.erb`
- Viewers should not reach this page (controller guard), but add fallback if needed

#### 3.2 Card creation

**File:** `app/views/columns/show/_add_card_button.html.erb`
- Wrap entire button in `if contributor?`

**File:** Board show view (triage stream)
- Hide "Add a card" controls for viewers

#### 3.3 Card detail actions

**File:** `app/views/cards/container/_closure_buttons.html.erb`
- Hide "Edit" button for viewers
- Hide "Mark as Done" / close/reopen buttons for viewers

**File:** `app/views/cards/columns/edit.html.erb`
- Hide entire column selection bar (Not Now, columns, Done) for viewers

**File:** `app/views/cards/container/_gild.html.erb`
- Hide gild/ungild button for viewers

**File:** `app/views/cards/display/common/_assignees.html.erb`
- Hide assignment management UI for viewers
- Still show who is assigned (read-only)

**File:** `app/views/cards/_messages.html.erb`
- Hide delete card button for viewers (already gated by `can_administer_card?` which now returns false for viewers)

#### 3.4 Comment form

**File:** `app/views/cards/comments/_new.html.erb`
- Show only when `@card.commentable_by?(Current.user)`
- For viewers on non-triage cards, show nothing (or a "read-only" indicator)

**File:** `app/views/cards/comments/_comment.html.erb`
- Hide edit/delete buttons for viewer comments on non-triage cards
- Keep edit/delete for viewer's own comments on triage cards

#### 3.5 Steps, tags, images

- Hide step add/edit/delete UI for viewers
- Hide tag toggle UI for viewers
- Hide "remove image" button for viewers

#### 3.6 Drag and drop

**File:** Column tag helper / card preview partials
- Set `draggable: false` for viewer users
- Omit `drop_url` data attributes from column containers for viewers
- This prevents both visual drag handles and functional drops

#### 3.7 Keyboard shortcuts

**File:** Card preview / board view templates
- Omit `data-card-not-now-url`, `data-card-closure-url`, `data-card-assign-to-self-url` attributes for viewers
- Without these URLs, the JS hotkey controllers will have no endpoint to POST to

#### 3.8 Navigation

- Hide links to account settings, user directory for viewers
- Viewers should see: boards list, board show, card show, activity timeline, notifications, personal settings

### Phase 4: Role Management UI

#### 4.1 Update role params

**File:** `app/controllers/users/roles_controller.rb`

```ruby
def role_params
  { role: params.require(:user)[:role].presence_in(%w[ member admin viewer ]) || "member" }
end
```

#### 4.2 Update role display

**File:** `app/helpers/users_helper.rb`

Add viewer case to `role_display_name` (or equivalent helper).

#### 4.3 Update role toggle UI

**File:** `app/views/account/settings/_user.html.erb`

Replace the current admin/member checkbox toggle with a three-option control (dropdown or radio group) supporting admin/member/viewer.

### Phase 5: Edge Cases

#### 5.1 API tokens

**File:** `app/controllers/my/access_tokens_controller.rb`

For viewers, restrict token creation to `read` permission only. Either hide the `write` option in the UI or enforce in the controller.

#### 5.2 Mention autocomplete

**File:** `app/controllers/prompts/users_controller.rb`

Keep viewers in the mention list (they can be mentioned and notified). But clearly distinguish them if possible.

#### 5.3 Board access on creation

**File:** `app/models/user/accessor.rb`

Viewers should still receive auto-access to `all_access` boards (same as members). The existing `unless: :system?` guard is sufficient.

#### 5.4 Join code

New users joining via join code still default to `member`. Admins must explicitly set the viewer role afterward.

## System-Wide Impact

### Interaction Graph

- Role change triggers `after_update_commit` -> cleans up assignments and drafted cards
- Assignment cleanup fires `after_destroy` callbacks on assignments -> may trigger events and notifications
- Comment creation by viewer fires standard `after_create_commit` -> event creation -> webhook dispatch -> notifications

### Error Propagation

- All viewer-restricted actions return `head :forbidden` (HTTP 403)
- No new error classes needed -- follows existing pattern
- Frontend JS hotkeys will silently fail (no URL to POST to) rather than showing errors

### State Lifecycle Risks

- **Demotion race condition**: If a viewer is being demoted while simultaneously editing a card, the request may succeed if it hits the server before the role update commits. This is acceptable given the existing optimistic concurrency approach.
- **Orphaned drafts**: Handled by cleanup callback. If the callback fails, drafted cards remain but the viewer cannot access them (controller guard blocks drafts controller).

### API Surface Parity

- All controller guards apply equally to HTML and JSON/API requests
- Bearer token authentication derives the user role from the identity/account pair, so API tokens respect the viewer role
- Webhooks continue to fire for viewer-created events (comments on triage cards)

## Acceptance Criteria

### Functional Requirements

- [x] Viewer can see board index listing accessible boards
- [x] Viewer can see board show page with triage stream and columns
- [x] Viewer can see card detail pages
- [x] Viewer can comment on cards awaiting triage (no column assigned)
- [x] Viewer cannot comment on triaged cards (in a column), closed cards, or postponed cards
- [x] Viewer can edit/delete their own comments on triage cards
- [x] Viewer cannot create cards or boards
- [x] Viewer cannot edit, close, reopen, postpone, gild, triage, or delete cards
- [x] Viewer cannot assign users to cards or self-assign
- [x] Viewer cannot manage steps, tags, or images on cards
- [x] Viewer cannot drag-and-drop cards between columns
- [x] Viewer cannot access account settings, board settings, user directory, join codes, webhooks
- [x] Viewer can use personal features: pins, watches, reactions, filters, notifications, search
- [x] Viewer can view the activity timeline
- [x] Admins can set a user's role to viewer via the role management UI
- [x] Demoting to viewer removes all card assignments
- [x] Demoting to viewer deletes drafted cards
- [x] `can_administer_board?` and `can_administer_card?` return false for viewers regardless of creator status
- [x] All UI controls for restricted actions are hidden for viewers
- [x] Keyboard shortcuts for restricted actions are disabled for viewers (no action URLs rendered)
- [x] Drag handles and drop zones are hidden for viewers
- [x] API tokens created by viewers are restricted to read-only

### Testing Requirements

- [x] Add `viewer` fixture user and corresponding identity fixture
- [x] Add access fixtures for viewer user on test boards
- [x] Test all 22+ mutating controllers return 403 for viewers
- [x] Test comment creation allowed on triage cards, forbidden on triaged cards
- [x] Test comment edit/delete allowed for own comments on triage cards
- [x] Test demotion cleanup: assignments removed, drafted cards deleted
- [x] Test `can_administer_board?` returns false for viewer board creators
- [x] Test `can_administer_card?` returns false for viewer card creators
- [x] Test `contributor?` returns true for owner/admin/member, false for viewer/system
- [x] Test role change UI allows setting viewer role
- [x] System tests verifying UI elements are hidden for viewers

## Dependencies & Risks

- **Large surface area**: 22+ controllers need guards, 15+ view files need conditionals. Risk of missing an endpoint.
  - Mitigation: Use centralized `ensure_contributor` guard pattern. Write a meta-test that verifies all POST/PATCH/DELETE routes return 403 for viewers (except explicitly allowed ones).
- **No database migration needed**: Role column is string-backed with no check constraint.
- **Backwards compatible**: Existing users are unaffected. No data migration.

## References & Research

### Key Files

- `app/models/user/role.rb` -- Role enum, permission methods, scopes
- `app/controllers/concerns/authorization.rb` -- `ensure_*` guard pattern
- `app/models/card/commentable.rb` -- `commentable?` method
- `app/models/card/assignable.rb` -- Assignment logic
- `app/models/card/triageable.rb` -- `awaiting_triage?` predicate
- `app/models/access.rb` -- Board access model
- `app/models/user/accessor.rb` -- User-board access management
- `app/controllers/users/roles_controller.rb` -- Role change controller
- `app/views/account/settings/_user.html.erb` -- Role toggle UI
- `app/helpers/users_helper.rb` -- Role display helper
- `app/models/identity/access_token.rb` -- Existing read/write permission pattern (precedent)

### Patterns to Follow

- `ensure_admin` pattern in `authorization.rb` for the new `ensure_contributor`
- `AccessToken#allows?` read/write pattern as precedent for viewer token restriction
- `after_update_commit` callback pattern for demotion cleanup
- Existing `admin?` / `owner?` override pattern for `contributor?` convenience method
