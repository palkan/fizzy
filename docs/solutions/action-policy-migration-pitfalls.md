---
title: "Action Policy Migration Pitfalls: Behavioral Regressions and Gotchas"
category: integration-issues
module: authorization
tags:
  - action_policy
  - authorization
  - migration
  - before_action
  - activerecord
  - relation_scope
  - regression
severity: high
components:
  - controllers
  - policies
  - views
  - before_action callbacks
  - ActiveRecord scopes
symptoms:
  - regular_users_locked_out_after_migration
  - business_logic_silently_dropped
  - activerecord_or_structural_compatibility_error
  - skip_authorization_not_found
  - wrong_http_status_codes
  - relation_scope_duplicates
root_cause: "Mechanical replacement of ad-hoc role checks with Action Policy without preserving before_action scoping, business logic guards, or accounting for ActiveRecord .or() structural requirements and Action Policy's implicit rule-to-action-name mapping."
date_solved: 2026-02-19
related:
  - docs/solutions/action-policy-authorization-patterns.md
---

# Action Policy Migration Pitfalls

## Problem Statement

When migrating from ad-hoc role checks (`ensure_admin`, `Current.user.admin?`) to Action Policy authorization, several categories of behavioral regressions can occur silently. Tests may pass while actual access control is broken — either too restrictive (locking users out) or too permissive (dropping business guards).

This document captures pitfalls discovered during a migration of ~40 controllers. For general patterns and architecture, see [Action Policy Authorization Patterns](action-policy-authorization-patterns.md).

## Pitfall 1: Over-Scoping `before_action` When Replacing Role Checks

**Severity**: Critical (locks users out)

When replacing `before_action :ensure_admin, only: :update` with a policy-based callback, it's easy to drop the `only:` constraint and accidentally gate ALL actions behind admin authorization.

```ruby
# BEFORE — only update requires admin
before_action :ensure_admin, only: :update

# WRONG — all actions now require admin
before_action :ensure_can_manage_account

# RIGHT — preserve original scoping
before_action :ensure_can_manage_account, only: :update
```

The `show` action also needs to satisfy `verify_authorized`. Use a permissive policy rule:

```ruby
def show
  authorize! @account, to: :show?  # AccountPolicy#show? returns true
  @users = @account.users.active
end
```

**Why tests may not catch this**: If test fixtures use an admin user by default, the over-scoped callback still passes.

**Prevention**: Before changing any `before_action`, note the `only:` / `except:` constraints and preserve them exactly.

## Pitfall 2: Dropping Business Logic When Migrating View Conditionals

**Severity**: Critical (changes visible behavior)

View conditionals often combine authorization with business logic. When migrating to `allowed_to?`, the business logic guard can be silently dropped.

```erb
<%# BEFORE — two concerns: business rule AND authorization %>
<% if Current.account.cancellable? && Current.user.owner? %>

<%# WRONG — drops cancellable? business rule %>
<% if allowed_to?(:destroy?, Current.account) %>

<%# RIGHT — business rule AND authorization %>
<% if Current.account.cancellable? && allowed_to?(:destroy?, Current.account) %>
```

**Key insight**: Authorization answers "who CAN do this?" Business logic answers "WHEN is this allowed?" Policies handle the first; model methods handle the second. Both must be present.

**Prevention**: For every view conditional being migrated, list each predicate separately and classify it as authorization (move to policy) or business logic (keep in view).

## Pitfall 3: ActiveRecord `.or()` Structural Compatibility in Relation Scopes

**Severity**: High (runtime error)

When a `relation_scope` needs to combine conditions with different join structures, `.or()` raises `ArgumentError: Relation passed to #or must be structurally compatible`.

```ruby
# WRONG — left side has no join, right side has joins
relation_scope do |scope|
  scope.where(all_access: true).or(
    scope.joins(:accesses).where(accesses: { user_id: user.id })
  )
end

# RIGHT — use left_joins on both sides for structural compatibility
relation_scope do |scope|
  scope.left_joins(:accesses).where(all_access: true).or(
    scope.left_joins(:accesses).where(accesses: { user_id: user.id })
  ).distinct
end
```

**Why `.distinct` is needed**: A user with explicit access to an `all_access` board would appear in both branches, producing duplicate rows.

**Why `left_joins` not `joins`**: `joins` (INNER JOIN) excludes `all_access` boards that have no access records. `left_joins` (LEFT OUTER JOIN) keeps them while still being structurally compatible.

## Pitfall 4: `authorize!` Default Rule Depends on Action Name

**Severity**: Medium (wrong authorization level)

Bare `authorize! @record` infers the rule from the current action name. In a `create` action, it checks `create?`, which falls back to `manage?`. For scoped concerns that only check visibility, this is too restrictive.

```ruby
# WRONG — in a create action, checks create? -> manage?
def set_column
  @column = Current.account.columns.find(params[:column_id])
  authorize! @column
end

# RIGHT — explicitly check visibility
def set_column
  @column = Current.account.columns.find(params[:column_id])
  authorize! @column, to: :show?
end
```

This matters for `handle_unauthorized` behavior: `:show?` failures produce 404 (hiding record existence), while `:manage?` failures produce 403.

**Prevention**: In scoped concerns (`BoardScoped`, `CardScoped`, `ColumnScoped`), always use `authorize! @record, to: :show?` explicitly. Reserve bare `authorize!` for actions where the action-inferred rule is correct.

## Pitfall 5: Action Policy Has No `skip_authorization` Method

**Severity**: Low (NameError at boot time)

Action Policy provides `verify_authorized` and `skip_verify_authorized`, but no `skip_authorization` class method. Calling it raises `NameError`.

**Options**:
1. Use `skip_verify_authorized` (Action Policy's built-in)
2. Define a no-op marker in the Authorization concern for documentation intent

```ruby
class_methods do
  def skip_authorization
    # No-op marker: documents that this controller intentionally
    # does not perform authorization (authentication is sufficient).
    # When verify_authorized is added to ApplicationController,
    # replace with skip_verify_authorized.
  end
end
```

## Pitfall 6: Find-Then-Authorize Changes Error Behavior

**Severity**: Low (behavior is equivalent when done correctly)

The old pattern (authorization-by-scoping) and new pattern (find-then-authorize) produce the same user-facing result, but the mechanism differs:

```ruby
# OLD — 404 from scoped query not finding the record
@board = Current.user.accessible_boards.find(params[:id])

# NEW — find succeeds, authorize! raises, handle_unauthorized converts to 404
@board = Current.account.boards.find(params[:id])
authorize! @board, to: :show?
```

**Prerequisite**: `handle_unauthorized` must convert `:show?` failures to `ActiveRecord::RecordNotFound`:

```ruby
def handle_unauthorized(exception)
  if exception.rule == :show?
    raise ActiveRecord::RecordNotFound
  else
    head :forbidden
  end
end
```

Without this handler, `:show?` failures return 403, which leaks the record's existence.

## Migration Checklist

For each controller being migrated:

- [ ] Note existing `before_action` constraints (`only:`, `except:`) — preserve them
- [ ] For each view conditional, classify predicates as authorization vs business logic
- [ ] Use `authorize! @record, to: :show?` in scoped concerns (not bare `authorize!`)
- [ ] Test with non-admin fixture users, not just admins
- [ ] Verify `relation_scope` uses compatible join structures for `.or()` and includes `.distinct`
- [ ] Run the full test suite after each controller (not just at the end)

## Related Files

- [Action Policy Authorization Patterns](action-policy-authorization-patterns.md) — general patterns and architecture
- `app/controllers/concerns/authorization.rb` — `handle_unauthorized`, `ensure_can_manage_account`
- `app/controllers/concerns/board_scoped.rb`, `card_scoped.rb`, `column_scoped.rb` — scoped concerns
- `app/policies/*.rb` — all policy files
- `docs/plans/2026-02-19-refactor-action-policy-integration-completeness-plan.md` — implementation plan
