---
title: Authorization Bypass Vulnerabilities in Viewer Role Implementation
date: 2026-02-21
category: security-issues
tags:
  - action-policy
  - authorization
  - access-control
  - viewer-role
  - policy-enforcement
  - code-review
modules:
  - app/policies
  - app/controllers/account/settings_controller
  - app/controllers/boards_controller
  - app/controllers/cards/columns_controller
  - app/controllers/cards/publishes_controller
  - app/controllers/cards/reactions_controller
  - app/views
  - test/policies
severity: high
resolution_time: moderate
---

# Authorization Gaps When Adding Viewer Role with Action Policy

## Problem Statement

When adding a new `viewer` role to Fizzy using Action Policy, multi-agent code review discovered 10 authorization gaps (2 Critical, 8 Important) across controllers, views, and policy tests. The viewer role was correctly defined at the policy layer, but several integration points allowed viewers to access or modify resources they shouldn't.

### Symptoms

- Account settings page accessible to viewers (should be admin-only)
- Controllers using `skip_authorization` bypassing all policy checks
- Views using direct role checks (`Current.user.viewer?`) instead of policy-based `allowed_to?`
- Controllers calling undefined policy rules (`publish?`)
- Inconsistent authorization patterns across similar controllers
- Policy scopes not returning correct records for viewers
- Missing test coverage for viewer role in 3 policy test files

## Root Cause

The viewer role was properly defined at the policy layer (`ApplicationPolicy` has `not_viewer?` check, individual policies use it), but the integration across the application was incomplete:

1. **Legacy authorization patterns** - Some controllers predated Action Policy and used `skip_authorization` or overly broad `verify_authorized` exceptions
2. **Mixed authorization styles** - Views used direct role checks instead of policy-based authorization
3. **Incomplete scope logic** - CardPolicy `relation_scope` didn't account for `all_access` boards
4. **Missing test coverage** - Three policy test files had zero viewer role test cases
5. **Undefined rules** - Controllers called non-existent policy rules
6. **Inconsistent patterns** - Similar controllers (card reactions vs comment reactions) used different authorization approaches

## Solution

### Fix 1: Account Settings (P1 - Critical)

`app/controllers/account/settings_controller.rb` - Extended `ensure_can_manage_account` to cover both show and update:

```ruby
# Before - only protected update, show was open
before_action :ensure_can_manage_account, only: :update

# After - protects both show and update
before_action :ensure_can_manage_account
```

### Fix 2: View Authorization - Settings Link (P2)

`app/views/my/menus/_settings.html.erb` - Replaced role check with policy check:

```erb
<%# Before %>
<% unless Current.user.viewer? %>

<%# After %>
<% if allowed_to?(:manage?, Current.account) %>
```

### Fix 3: Undefined publish? Rule (P2)

`app/controllers/cards/publishes_controller.rb` - Used existing `manage?` rule:

```ruby
# Before - calls undefined rule
authorize! @card, to: :publish?

# After - uses existing CRUD-like rule
authorize! @card, to: :manage?
```

### Fix 4: Reaction Authorization Consistency (P2)

`app/controllers/cards/reactions_controller.rb` - Aligned with comment reactions pattern:

```ruby
# Before - inconsistent with Cards::Comments::ReactionsController
authorize! @card, to: :manage?

# After - matches comment reactions, delegates to ReactionPolicy
authorize! Reaction
```

### Fix 5: Cards::ColumnsController (P2)

Replaced `skip_authorization` with proper Action Policy integration:

```ruby
# Before
class Cards::ColumnsController < ApplicationController
  skip_authorization

# After
class Cards::ColumnsController < ApplicationController
  include CardScoped
  verify_authorized

  def edit
    authorize! @card, to: :manage?
    # ...
  end
end
```

### Fix 6: BoardsController verify_authorized (P2)

Reduced overly broad exceptions:

```ruby
# Before - new and create unnecessarily excluded
verify_authorized except: %i[ index new create ]

# After - only index excluded
verify_authorized except: :index
```

### Fix 7: CardPolicy Relation Scope (P2)

Updated scope to include `all_access` boards:

```ruby
# Before - missed all_access boards
scope.joins(board: :accesses).where(accesses: { user_id: user.id })

# After - includes all_access boards
scope.left_joins(board: :accesses).where(boards: { all_access: true }).or(
  scope.left_joins(board: :accesses).where(accesses: { user_id: user.id })
).distinct
```

### Fix 8: Missing Viewer Tests (P2)

Added viewer-specific test cases to AccountPolicyTest, ColumnPolicyTest, and WebhookPolicyTest covering `manage?`, `create?`, `show?`, `update?`, and `destroy?` rules.

## Verification

- 101 policy tests pass (0 failures)
- 388 controller tests pass (0 failures)

## Prevention Strategies

### Checklist for Adding a New Role

- [ ] Audit every policy file: does each rule handle the new role correctly?
- [ ] Search for `skip_authorization` — is each still justified?
- [ ] Search for `verify_authorized except:` — are the exceptions minimal?
- [ ] Search views for direct role checks (`current_user.admin?`, `Current.user.viewer?`) — convert to `allowed_to?`
- [ ] Verify all `authorize! to: :rule?` calls reference defined policy methods
- [ ] Check `relation_scope` blocks account for all access patterns (e.g., `all_access` boards)
- [ ] Add test fixture for the new role with appropriate access records
- [ ] Add viewer test cases to every policy test file (show, create, manage, destroy)
- [ ] Compare authorization patterns across similar controllers for consistency

### Key Insights

1. **Policies are the source of truth** — if a controller action lacks a corresponding policy rule, it's a gap waiting for the next role addition.
2. **Scopes are invisible failures** — a controller might authorize `:show?` correctly, but if `relation_scope` doesn't filter for the new role, restricted data leaks.
3. **Tests reveal gaps early** — writing tests for the new role in all policies forces thinking through each rule.
4. **Consistency across similar resources** — apply identical authorization logic to related controllers (cards, comments, reactions). Inconsistency is where bugs hide.
5. **Views should ask policies, not check roles** — `allowed_to?(:manage?, resource)` is future-proof; `current_user.viewer?` breaks with the next role.

## Related Documentation

- Plan: `docs/plans/2026-02-21-feat-add-viewer-role-plan.md`
- Branch: `viewer/layers/compound`
- Style guide: `STYLE.md` (Action Policy authorization section)
