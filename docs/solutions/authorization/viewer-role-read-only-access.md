---
title: Add Viewer Role for Read-Only Board Access with Triage Commenting
type: feat
status: implemented
date: 2026-02-20
problem_type:
  - feature_pattern
  - authorization
  - role_system
components:
  - User::Role
  - Card::Commentable
  - Authorization concern
  - 22+ controllers
  - 15+ view templates
tags:
  - role-based-access-control
  - viewer-role
  - read-only-access
  - authorization
  - triage-workflow
  - defense-in-depth
  - enumerated-roles
difficulty: high
impact: high
---

# Viewer Role: Read-Only Access with Triage Commenting

## Problem

Fizzy had four roles: `owner`, `admin`, `member`, and `system`. The lowest non-system role was `member`, which granted full create/edit/delete access. There was no read-only option.

Teams needed a way to give stakeholders, clients, or observers visibility into project boards without granting them the ability to modify work items. The gap between "full member access" and "no access at all" was too wide.

## Solution

A new `viewer` role provides read-only access to boards and cards, with one narrow write exception: viewers can comment on cards awaiting triage (not yet assigned to a column). The implementation uses defense-in-depth across four layers.

### 1. Model Layer

**Role enum expansion** (`app/models/user/role.rb`):

```ruby
enum :role, %i[ owner admin member viewer system ].index_by(&:itself), scopes: false
```

No database migration needed -- the role column is string-backed with no check constraint.

**New `contributor?` predicate** distinguishes users who can modify content:

```ruby
def contributor?
  owner? || admin? || member?
end
```

**Hardened permission methods** gate on `contributor?`:

```ruby
def can_administer_board?(board)
  contributor? && (admin? || board.creator == self)
end
```

**Demotion cleanup** -- when demoted to viewer, assignments and drafted cards are removed:

```ruby
after_update_commit :cleanup_on_viewer_demotion, if: :viewer?

def cleanup_on_viewer_demotion
  return unless role_previously_changed? && viewer?
  assignments.destroy_all
  Card.where(creator: self).drafted.destroy_all
end
```

### 2. Comment Gating

**Role-aware commenting** (`app/models/card/commentable.rb`):

```ruby
def commentable_by?(user)
  commentable? && (user.contributor? || awaiting_triage?)
end
```

Contributors can comment on any published card. Viewers can only comment on cards awaiting triage, where their feedback on incoming items is most valuable.

### 3. Authorization Layer

**Centralized guard** (`app/controllers/concerns/authorization.rb`):

```ruby
def ensure_contributor
  head :forbidden unless Current.user.contributor?
end
```

Applied as `before_action :ensure_contributor` across 22+ controllers covering all mutating endpoints. The positive `contributor?` check means any future roles below member are automatically blocked.

**Controller-specific handling**:
- Comments: `ensure_can_comment` uses `commentable_by?` for role-aware access
- Assignments: user lists use `.contributor` scope, excluding viewers from being assignable
- API tokens: forced to read-only for viewers (`permitted[:permission] = "read"`)
- Role management: allowed roles updated to include `viewer`

### 4. View Layer

A `contributor?` helper in `ApplicationHelper` provides clean view conditionals:

```ruby
def contributor?
  Current.user&.contributor?
end
```

UI elements hidden for viewers across 15+ templates:
- Board/card/column creation buttons
- Edit, close, reopen, and gild controls
- Drag-and-drop attributes (no `drag_and_drop_url`, `draggable` set to false)
- Assignment interactive controls (replaced with read-only avatar display)
- Step checkboxes (replaced with read-only text)
- Keyboard shortcut data attributes (no endpoint URLs for JS hotkey controllers)
- Settings and invite links
- Comment form (only shown when `commentable_by?` returns true)

### 5. Testing

**Fixtures**: New `pat` viewer user with identity, session, and board access records.

**Dedicated authorization test** (`test/controllers/viewer_authorization_test.rb`): 30+ test cases verifying:
- All mutating endpoints return 403 for viewers
- Viewers can view boards, cards, activity timeline, and search
- Viewers can comment on triage cards but not triaged cards
- Viewers can edit/delete their own comments on triage cards only

**Model tests** (`test/models/user/role_test.rb`): 11 cases covering predicates, scopes, permission gating, and demotion cleanup.

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Positive `contributor?` check | Future roles below member auto-blocked without code changes |
| String-backed enum | No migration needed; backward compatible |
| Triage-only commenting | Viewers provide feedback during intake, not on in-progress work |
| Creator permissions revoked on demotion | Prevents privilege retention even for items user created |
| Frontend + backend enforcement | Defense in depth; never rely solely on UI suppression |
| API token read-only forcing | Prevents privilege escalation via token-based automation |

## Prevention / Best Practices

When adding new mutating controllers or actions in the future:

1. Add `before_action :ensure_contributor` to any new controller that modifies data
2. Use `contributor?` helper in views to conditionally render interactive controls
3. When adding new roles, decide whether they should be contributors or not
4. Test authorization for new endpoints in `test/controllers/viewer_authorization_test.rb`
5. Remember that omitting UI controls is not sufficient -- always enforce at the controller level

## Related

- Plan: `docs/plans/2026-02-20-feat-add-viewer-role-plan.md`
