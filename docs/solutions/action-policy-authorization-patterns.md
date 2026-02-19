---
title: "Action Policy Authorization Patterns"
category: architecture
module: authorization
tags:
  - action_policy
  - authorization
  - policies
  - controllers
  - views
  - testing
symptoms:
  - custom_policy_rules
  - role_checks_in_views
  - role_predicates_outside_policies
  - missing_authorization_contexts
  - verbose_controller_authorization
date_solved: 2026-02-03
---

# Action Policy Authorization Patterns

## Problem Statement

Migrating from ad-hoc authorization (role checks scattered in controllers/views) to Action Policy requires establishing consistent patterns for:
- Policy rule design (CRUD vs custom actions)
- Authorization contexts for nested resources
- View authorization without direct role checks
- Minimal controller authorization code
- Proper testing approaches

## Solution

### Architecture Overview

```
app/policies/
├── application_policy.rb      # Base policy with shared contexts
├── account_policy.rb          # Account-level rules
├── board_policy.rb            # Board access + admin rules
├── card_policy.rb             # Card visibility + management
├── column_policy.rb           # Column management (via board)
├── comment_policy.rb          # Comment ownership rules
├── user_policy.rb             # User management rules
└── webhook_policy.rb          # Webhook management (via board)

app/controllers/concerns/
├── authorization.rb           # Base authorization concern
├── board_scoped.rb            # Board context registration
└── card_scoped.rb             # Card context registration
```

### Key Design Decisions

#### 1. Minimal CRUD-like Rules

Keep policies small with standard CRUD rules. Action Policy provides:
- Default rule: `:manage?` (fallback for unknown rules)
- Default alias: `:new? -> :create?`

```ruby
class ApplicationPolicy < ActionPolicy::Base
  authorize :user
  authorize :account

  delegate :admin?, :owner?, to: :user

  def show?
    false  # Override per policy
  end

  def manage?
    false  # Override per policy
  end
end
```

Custom rules indicate wrong design—introduce a new resource instead:

```ruby
# Bad - custom action rule
class CardPolicy
  def can_archive?  # Wrong!
end

# Good - new resource
class Cards::ArchivesController
  def create
    authorize!  # Uses ArchivePolicy#create?
  end
end
```

#### 2. Authorization Contexts for Parent Records

For `create?` and `index?` rules where `record` isn't available, use authorization contexts:

```ruby
class WebhookPolicy < ApplicationPolicy
  authorize :board, optional: true  # Declared context

  def index?
    allowed_to?(:manage?, board)  # Uses context
  end

  def create?
    allowed_to?(:manage?, board)  # Uses context
  end

  def show?
    allowed_to?(:manage?, record.board)  # Uses record
  end

  def manage?
    allowed_to?(:manage?, record.board)  # Uses record
  end
end
```

Register contexts in scoped concerns:

```ruby
module BoardScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_board
    authorize :board, through: -> { @board }  # Makes @board available to policies
  end

  private
    def set_board
      @board = Current.account.boards.find_by!(slug: params[:board_id])
      authorize! @board, to: :show?  # Ensures board visibility
    end
end
```

#### 3. `check?` for Reason Tracking

Use `check?` instead of direct predicate calls to enable failure reason tracking:

```ruby
class AccountPolicy < ApplicationPolicy
  def manage?
    check?(:admin?)  # Tracks "admin?" as the failure reason
  end

  def destroy?
    check?(:owner?)  # Tracks "owner?" as the failure reason
  end
end
```

#### 4. `allowed_to?` for Policy Composition

Delegate to other policies for nested authorization:

```ruby
class CommentPolicy < ApplicationPolicy
  authorize :card, optional: true

  def create?
    allowed_to?(:show?, card)  # Delegates to CardPolicy
  end

  def show?
    allowed_to?(:show?, record.card)  # Delegates to CardPolicy
  end

  def manage?
    allowed_to?(:show?) && check?(:creator?)  # Combines delegation + check
  end

  def creator?
    record.creator == user
  end
end
```

#### 5. Minimal Controller Authorization

Keep authorization code minimal in controllers:

```ruby
class WebhooksController < ApplicationController
  include BoardScoped

  before_action :set_webhook, except: %i[ index new create ]

  def index
    authorize!  # Uses WebhookPolicy with board context
    set_page_and_extract_portion_from @board.webhooks.ordered
  end

  def create
    authorize!
    webhook = @board.webhooks.create!(webhook_params)
    redirect_to webhook
  end

  def show
    # Authorization happens in set_webhook
  end

  private
    def set_webhook
      @webhook = @board.webhooks.find(params[:id])
      authorize! @webhook
    end
end
```

#### 6. Views Use `allowed_to?` Not Role Checks

```erb
<%# Good - policy-based %>
<%= link_to_webhooks(@board) if allowed_to?(:index?, Webhook, context: {board: @board}) %>
<%= link_to_edit_board @board if allowed_to?(:manage?, @board) %>
<%= render "settings/entropy" if allowed_to?(:manage?, Current.account) %>

<%# Bad - direct role check %>
<%= link_to_webhooks(@board) if current_user.admin? %>
<%= link_to_edit_board @board if current_user.owner? || @board.creator == current_user %>
```

### Error Handling

Return 404 for visibility failures, 403 for permission failures:

```ruby
module Authorization
  extend ActiveSupport::Concern

  included do
    rescue_from ActionPolicy::Unauthorized, with: :handle_unauthorized
  end

  private
    def handle_unauthorized(exception)
      if exception.rule == :show?
        raise ActiveRecord::RecordNotFound  # 404 - don't leak existence
      else
        head :forbidden  # 403 - record exists but action denied
      end
    end
end
```

## Migration Checklist

### For Each Controller

1. **Identify parent resources**: Does this controller operate on nested resources?
2. **Add scoped concern**: Include `BoardScoped` or `CardScoped` if applicable
3. **Add `authorize!` calls**:
   - In `index`, `new`, `create` actions (before any work)
   - In `set_*` callbacks for `show`, `edit`, `update`, `destroy`
4. **Remove role checks**: Replace `current_user.admin?` with `authorize!` or `allowed_to?`
5. **Add authorization tests**: Use `assert_authorized_to` in controller tests

### For Each Policy

1. **Define only necessary rules**: `show?` and `manage?` are usually sufficient
2. **Use `check?`**: For predicate methods to enable reason tracking
3. **Use `allowed_to?`**: For delegating to other policies
4. **Add authorization context**: If `create?` or `index?` needs parent record
5. **Add `relation_scope`**: If controller uses `authorized_scope` for collections

### For Views

1. **Replace role checks**: `current_user.admin?` → `allowed_to?(:manage?, resource)`
2. **Use context for new records**: `allowed_to?(:create?, Model, context: {parent: @parent})`
3. **Remove role predicates from models**: They should only exist for policy use

### For Models

1. **Remove authorization scopes**: Move to policy's `relation_scope`
2. **Keep role predicates private**: Only policies should call `admin?`, `owner?`
3. **Remove `can_*?` methods**: Authorization belongs in policies

## Gotchas & Lessons Learned

### 1. Context Must Be Registered Before Use

**Problem**: Policy raises "Unknown authorization context: board"

**Solution**: Ensure the controller includes the scoped concern that registers the context:

```ruby
class WebhooksController < ApplicationController
  include BoardScoped  # Registers: authorize :board, through: -> { @board }
end
```

### 2. Optional Context for Existing Records

**Problem**: Policy fails when authorizing existing record with declared context

**Solution**: Mark context as `optional: true` when it's only needed for some rules:

```ruby
class WebhookPolicy < ApplicationPolicy
  authorize :board, optional: true  # Required for create?, not for show?

  def create?
    allowed_to?(:manage?, board)  # Uses context
  end

  def show?
    allowed_to?(:manage?, record.board)  # Uses record's association
  end
end
```

### 3. View Context Syntax

**Problem**: `allowed_to?(:create?, Webhook, board: @board)` doesn't work

**Solution**: Context must be passed as `context:` hash:

```ruby
# Wrong
allowed_to?(:create?, Webhook, board: @board)

# Correct
allowed_to?(:create?, Webhook, context: {board: @board})
```

### 4. Testing Policies Directly

**Problem**: How to test policy rules in isolation?

**Solution**: Use `policy.apply(:rule?)` pattern:

```ruby
test "board admin can manage webhooks" do
  policy = WebhookPolicy.new(@webhook, user: users(:david), account: @account)
  assert policy.apply(:show?)
  assert policy.apply(:update?)
end

test "create uses board context" do
  # Pass context as named argument, no record
  policy = WebhookPolicy.new(board: @board, user: users(:david), account: @account)
  assert policy.apply(:create?)
end
```

### 5. Default Rule Fallback

**Problem**: `update?` returns true unexpectedly

**Reason**: Action Policy falls back to `manage?` for undefined rules

**Solution**: This is intentional. Only define rules that differ from `manage?`:

```ruby
class BoardPolicy < ApplicationPolicy
  def show?
    # Explicit - visibility differs from management
    record.all_access? || check?(:has_access?)
  end

  def manage?
    # Explicit - defines who can edit/update/destroy
    check?(:board_admin?)
  end

  # update?, edit?, destroy? all use manage? automatically
end
```

## Testing Patterns

### Controller Tests with `assert_authorized_to`

```ruby
class ActionDispatch::IntegrationTest
  include ActionPolicy::TestHelper
end

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  test "index authorizes" do
    assert_authorized_to(:index?, Webhook) do
      get board_webhooks_path(boards(:writebook))
    end
  end

  test "create authorizes" do
    assert_authorized_to(:create?, Webhook) do
      post board_webhooks_path(boards(:writebook)), params: { webhook: valid_params }
    end
  end

  test "show authorizes specific record" do
    webhook = webhooks(:active)
    assert_authorized_to(:show?, webhook) do
      get board_webhook_path(webhook.board, webhook)
    end
  end
end
```

### Policy Unit Tests

```ruby
class BoardPolicyTest < ActiveSupport::TestCase
  setup do
    @account = accounts("37s")
    @board = boards(:writebook)
  end

  test "board creator can manage" do
    policy = BoardPolicy.new(@board, user: users(:david), account: @account)
    assert policy.apply(:manage?)
  end

  test "account admin can manage any board" do
    policy = BoardPolicy.new(@board, user: users(:kevin), account: @account)
    assert policy.apply(:manage?)
  end

  test "member with access can view" do
    policy = BoardPolicy.new(@board, user: users(:jz), account: @account)
    assert policy.apply(:show?)
  end

  test "member without access cannot view" do
    # Remove access
    @board.accesses.where(user: users(:jz)).destroy_all
    policy = BoardPolicy.new(@board, user: users(:jz), account: @account)
    assert_not policy.apply(:show?)
  end
end
```

## Related Files

- `app/policies/*.rb` - All policy classes
- `app/controllers/concerns/authorization.rb` - Base authorization concern
- `app/controllers/concerns/board_scoped.rb` - Board context registration
- `app/controllers/concerns/card_scoped.rb` - Card context registration
- `test/policies/*.rb` - Policy unit tests
- `test/controllers/*_test.rb` - Controller authorization tests

## Prevention Strategies

1. **Add `verify_authorized`**: Uncomment in `Authorization` concern to catch missing authorizations
2. **Review PRs for role checks**: Flag `current_user.admin?` outside policies
3. **Use scoped concerns**: Always use `BoardScoped`/`CardScoped` for nested resources
4. **Test authorization**: Every controller action should have `assert_authorized_to` test
5. **Keep policies small**: More than 5-6 rules is a smell—consider new resources
