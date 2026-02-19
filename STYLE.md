
# Style

We aim to write code that is a pleasure to read, and we have a lot of opinions about how to do it well. Writing great code is an essential part of our programming culture, and we deliberately set a high bar for every code change anyone contributes. We care about how code reads, how code looks, and how code makes you feel when you read it.

We love discussing code. If you have questions about how to write something, or if you detect some smell you are not quite sure how to solve, please ask away to other programmers. A Pull Request is a great way to do this.

When writing new code, unless you are very familiar with our approach, try to find similar code elsewhere to look for inspiration.

## Conditional returns

In general, we prefer to use expanded conditionals over guard clauses.

```ruby
# Bad
def todos_for_new_group
  ids = params.require(:todolist)[:todo_ids]
  return [] unless ids
  @bucket.recordings.todos.find(ids.split(","))
end

# Good
def todos_for_new_group
  if ids = params.require(:todolist)[:todo_ids]
    @bucket.recordings.todos.find(ids.split(","))
  else
    []
  end
end
```

This is because guard clauses can be hard to read, especially when they are nested.

As an exception, we sometimes use guard clauses to return early from a method:

* When the return is right at the beginning of the method.
* When the main method body is not trivial and involves several lines of code.

```ruby
def after_recorded_as_commit(recording)
  return if recording.parent.was_created?

  if recording.was_created?
    broadcast_new_column(recording)
  else
    broadcast_column_change(recording)
  end
end
```

## Methods ordering

We order methods in classes in the following order:

1. `class` methods
2. `public` methods with `initialize` at the top.
3. `private` methods

## Invocation order

We order methods vertically based on their invocation order. This helps us to understand the flow of the code.

```ruby
class SomeClass
  def some_method
    method_1
    method_2
  end

  private
    def method_1
      method_1_1
      method_1_2
    end
  
    def method_1_1
      # ...
    end
  
    def method_1_2
      # ...
    end
  
    def method_2
      method_2_1
      method_2_2
    end
  
    def method_2_1
      # ...
    end
  
    def method_2_2
      # ...
    end
end
```

## To bang or not to bang

Should I call a method `do_something` or `do_something!`?

As a general rule, we only use `!` for methods that have a correspondent counterpart without `!`. In particular, we don’t use `!` to flag destructive actions. There are plenty of destructive methods in Ruby and Rails that do not end with `!`.

## Visibility modifiers

We don't add a newline under visibility modifiers, and we indent the content under them.

```ruby
class SomeClass
  def some_method
    # ...
  end

  private
    def some_private_method_1
      # ...
    end

    def some_private_method_2
      # ...
    end
end
```

If a module only has private methods, we mark it `private` at the top and add an extra new line after but don't indent.

```ruby
module SomeModule
  private
  
  def some_private_method
    # ...
  end
end
```

## CRUD controllers

We model web endpoints as CRUD operations on resources (REST). When an action doesn't map cleanly to a standard CRUD verb, we introduce a new resource rather than adding custom actions.

```ruby
# Bad
resources :cards do
  post :close
  post :reopen
end

# Good
resources :cards do
  resource :closure
end
```

## Controller and model interactions

In general, we favor a [vanilla Rails](https://dev.37signals.com/vanilla-rails-is-plenty/) approach with thin controllers directly invoking a rich domain model. We don't use services or other artifacts to connect the two.

Invoking plain Active Record operations is totally fine:

```ruby
class Cards::CommentsController < ApplicationController
  def create
    @comment = @card.comments.create!(comment_params)
  end
end
```

For more complex behavior, we prefer clear, intention-revealing model APIs that controllers call directly:

```ruby
class Cards::GoldnessesController < ApplicationController
  def create
    @card.gild
  end
end
```

When justified, it is fine to use services or form objects, but don't treat those as special artifacts:

```ruby
Signup.new(email_address: email_address).create_identity
```

## Run async operations in jobs

As a general rule, we write shallow job classes that delegate the logic itself to domain models:

* We typically use the suffix `_later` to flag methods that enqueue a job.
* A common scenario is having a model class that enqueues a job that, when executed, invokes some method in that same class. In this case, we use the suffix `_now` for the regular synchronous method.

```ruby
module Event::Relaying
  extend ActiveSupport::Concern

  included do
    after_create_commit :relay_later
  end

  def relay_later
    Event::RelayJob.perform_later(self)
  end

  def relay_now
    # ...
  end
end

class Event::RelayJob < ApplicationJob
  def perform(event)
    event.relay_now
  end
end
```

## Action Policy authorization

We use Action Policy for authorization. Policies are the source of truth for all authorization logic.

### Keep rules CRUD-like

Policies should have a small number of rules that map to CRUD operations. Custom rules (like `can_archive?` or `can_publish?`) are a sign of wrong design—introduce a new resource instead.

```ruby
# Good - CRUD rules only
class CardPolicy < ApplicationPolicy
  def show?
    allowed_to?(:show?, record.board)
  end

  def manage?
    allowed_to?(:show?, record.board)
  end

  def destroy?
    allowed_to?(:manage?) && check?(:can_administer?)
  end
end

# Bad - custom action rules
class CardPolicy < ApplicationPolicy
  def can_archive?      # Should be ArchivePolicy#create?
  def can_publish?      # Should be PublicationPolicy#create?
  def can_assign?       # Should be AssignmentPolicy#create?
end
```

### Default rule and aliases

Action Policy provides default rule `:manage?` and alias `:new? -> :create?`. Unknown rules fall back to `:manage?`, so you only need to define rules that differ from it:

```ruby
class BoardPolicy < ApplicationPolicy
  # show? is defined (visibility differs from manage?)
  def show?
    record.all_access? || check?(:has_access?)
  end

  # manage? is defined (admin-only actions)
  def manage?
    check?(:board_admin?)
  end

  # update?, edit?, destroy? all fall back to manage? automatically
  # new? falls back to create? automatically
end
```

### Use `check?` for reason tracking

Use `check?` instead of calling predicate methods directly. This enables failure reasons feature:

```ruby
# Good - enables failure reason tracking
def manage?
  check?(:admin?)
end

def destroy?
  check?(:owner?)
end

# Bad - loses reason information
def manage?
  admin?
end
```

### Use `allowed_to?` for policy composition

When a policy rule depends on another resource's authorization, delegate via `allowed_to?`:

```ruby
class CardPolicy < ApplicationPolicy
  def show?
    allowed_to?(:show?, record.board)  # Delegates to BoardPolicy
  end
end

class CommentPolicy < ApplicationPolicy
  def show?
    allowed_to?(:show?, record.card)  # Delegates to CardPolicy
  end

  def manage?
    allowed_to?(:show?) && check?(:creator?)
  end
end
```

### Authorization contexts for parent records

When a policy needs the parent record for `create?` or `index?` rules (where `record` isn't set), declare an authorization context:

```ruby
class CommentPolicy < ApplicationPolicy
  authorize :card, optional: true

  def create?
    allowed_to?(:show?, card)  # Uses context, not record
  end
end

class WebhookPolicy < ApplicationPolicy
  authorize :board, optional: true

  def index?
    allowed_to?(:manage?, board)
  end

  def create?
    allowed_to?(:manage?, board)
  end
end
```

Register contexts in scoped controller concerns:

```ruby
module CardScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_card
    authorize :card, through: -> { @card }
  end
end

module BoardScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_board
    authorize :board, through: -> { @board }
  end
end
```

### Controller authorization patterns

Keep authorization code minimal. Use `authorize!` in `before_action` callbacks for record lookups:

```ruby
class WebhooksController < ApplicationController
  include BoardScoped

  before_action :set_webhook, except: %i[ index new create ]

  def index
    authorize!  # Authorizes with WebhookPolicy using board context
    set_page_and_extract_portion_from @board.webhooks.ordered
  end

  def create
    authorize!
    webhook = @board.webhooks.create!(webhook_params)
    redirect_to webhook
  end

  private
    def set_webhook
      @webhook = @board.webhooks.find(params[:id])
      authorize! @webhook  # Authorizes the specific record
    end
end
```

### Scopes belong in policies, not models

Define `relation_scope` blocks in policies to filter collections:

```ruby
# Good - scope in policy
class BoardPolicy < ApplicationPolicy
  relation_scope do |scope|
    scope.joins(:accesses).where(accesses: { user_id: user.id })
  end
end

# Bad - scope in model
class Board < ApplicationRecord
  scope :accessible_by, ->(user) { joins(:accesses).where(accesses: { user_id: user.id }) }
end
```

### Find + authorize for single records

For single record lookups, find the record first, then authorize. Use `authorized_scope` only for collections:

```ruby
# Good - find then authorize
def set_card
  @card = Current.account.cards.find_by!(slug: params[:id])
  authorize! @card
end

# Bad - scope for single record
def set_card
  @card = authorized_scope(Card.all).find_by!(slug: params[:id])
end
```

### Return 404 for visibility failures

When `show?` fails, return 404 to avoid leaking record existence. Return 403 for other rule failures:

```ruby
def handle_unauthorized(exception)
  if exception.rule == :show?
    raise ActiveRecord::RecordNotFound
  else
    head :forbidden
  end
end
```

### Views use policies, not role checks

Replace direct role checks in views with `allowed_to?`:

```ruby
# Good - uses policy
<%= link_to_webhooks(@board) if allowed_to?(:index?, Webhook, context: {board: @board}) %>
<%= link_to_edit_board @board if allowed_to?(:manage?, @board) %>

# Bad - direct role check
<%= link_to_webhooks(@board) if current_user.admin? %>
<%= link_to_edit_board @board if current_user.owner? || @board.creator == current_user %>
```

### No role predicate methods in models

Role predicates (`admin?`, `owner?`) should only be used within policies. Don't call them from controllers or views:

```ruby
# Good - policy encapsulates the logic
class AccountPolicy < ApplicationPolicy
  def manage?
    check?(:admin?)
  end

  def destroy?
    check?(:owner?)
  end
end

# Then in controller/view
authorize! Current.account, to: :manage?

# Bad - role check outside policy
if current_user.admin?
  # ...
end
```

### Testing with ActionPolicy::TestHelper

Use `assert_authorized_to` in controller tests to verify authorization:

```ruby
class ActionDispatch::IntegrationTest
  include ActionPolicy::TestHelper
end

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  test "index authorizes with WebhookPolicy" do
    assert_authorized_to(:index?, Webhook) do
      get board_webhooks_path(boards(:writebook))
    end
  end

  test "show authorizes the specific webhook" do
    webhook = webhooks(:active)
    assert_authorized_to(:show?, webhook) do
      get board_webhook_path(webhook.board, webhook)
    end
  end
end
```

Test policy rules directly with `policy.apply`:

```ruby
class WebhookPolicyTest < ActiveSupport::TestCase
  test "board admin can manage webhooks" do
    policy = WebhookPolicy.new(@webhook, user: users(:david), account: @account)
    assert policy.apply(:show?)
    assert policy.apply(:update?)
    assert policy.apply(:destroy?)
  end

  test "non-admin cannot manage webhooks" do
    policy = WebhookPolicy.new(@webhook, user: users(:jz), account: @account)
    assert_not policy.apply(:show?)
  end

  test "create uses board context" do
    policy = WebhookPolicy.new(board: @board, user: users(:david), account: @account)
    assert policy.apply(:create?)
  end
end
```
