## Development

### Setting up

First, get everything installed and configured with:

```sh
bin/setup
bin/setup --reset # Reset the database and seed it
```

And then run the development server:

```sh
bin/dev
```

You'll be able to access the app in development at http://app.fizzy.localhost:3006.

To log in, enter `david@example.com`. In development the verification code is shown on the page itself, under "Psst, here's your code" — no need to check your email.

### Web Push Notifications

Fizzy uses VAPID (Voluntary Application Server Identification) keys to send browser push notifications. For notifications to work in development you'll need to generate a key pair and set these environment variables:

- `VAPID_PRIVATE_KEY`
- `VAPID_PUBLIC_KEY`

Generate them with the `web-push` gem:

```ruby
vapid_key = WebPush.generate_key

puts "VAPID_PRIVATE_KEY=#{vapid_key.private_key}"
puts "VAPID_PUBLIC_KEY=#{vapid_key.public_key}"
```

### Running tests

For fast feedback loops, unit tests can be run with:

```sh
bin/rails test
```

The full continuous integration tests can be run with:

```sh
bin/ci
```

### Mutation testing

Line coverage tells you a line ran; [Mutineer](https://github.com/davidteren/mutineer) tells you whether the tests would notice it changing. It makes small changes to the code (`>=` to `>`, `&&` to `||`, deleting a statement) and runs the tests that cover each changed line. A change that every test still passes is a *surviving mutant*, pointing at behavior no test pins down.

```sh
bin/mutineer app/models/card.rb                          # one file, against its paired test
bin/mutineer app/models app/controllers --since origin/main  # only the lines changed on your branch
bin/mutineer app/controllers --no-fail-fast              # every survivor in a directory
```

Each source runs against its conventionally paired test (`app/models/card.rb` with `test/models/card_test.rb`, `app/controllers/cards_controller.rb` with `test/controllers/cards_controller_test.rb`); pass `--test FILE` to add others. A source without a test at that path is skipped with a `no test found by convention` warning, so give code worth mutating a test file that mirrors its path, `concerns/` included (`app/models/concerns/storage/totaled.rb` with `test/models/concerns/storage/totaled_test.rb`). For shared controller concerns tested through their controllers, like `BoardScoped`, give Mutineer the controller tests and let coverage pick the ones that reach each line:

```sh
bin/mutineer app/controllers/concerns $(find test/controllers test/integration -name '*_test.rb' | sed 's/^/--test /')
```

Mutineer only mutates method bodies, so scopes, callbacks and associations declared in class bodies aren't covered. Settings live in `.mutineer.yml`, and `test/mutineer_boot.rb` adapts the app to how Mutineer loads mutants.

#### Working with mutation testing

Run it once your tests are green and before opening a pull request: it checks whether the tests you just wrote pin down the code you just wrote.

Mutation testing is slow, since it runs the covering tests once for every mutant. One file takes from several seconds to a minute or two, a whole directory like `app/models` takes around five minutes, and passing many `--test` files adds minutes of coverage capture before the first mutant runs. So don't run it on every save or test run: run it at the end of a change, scoped to it with `--since origin/main` or `--only`, and leave whole-directory scans for occasional check-ups.

1. **Mutate what you changed.** `bin/mutineer app/models app/controllers --since origin/main` only touches the lines in your diff and only runs the tests that cover them. Use `--only 'Card#postpone'` for a tight loop on one method.
2. **Go through the survivors.** Each one is a change no test noticed:
   - Usually it's a missing assertion: add a test that fails on the mutant, such as a boundary value, the other branch, or a side effect you never checked.
   - If nothing could ever notice the change, the code may be dead or redundant.
   - If the mutant behaves exactly like the original (an *equivalent mutant*, like `rescue nil` becoming `rescue true` where the value is unused), suppress it by id with `bundle exec mutineer triage` or `ignore:` in `.mutineer.yml`, with a reason.
3. **Repeat** until only accepted survivors remain.
4. **Reach shared code explicitly.** When your change touches a controller concern, pass the controller and integration tests that use it with `--test`. For branchy controller code, add `--operators condition_true,condition_false,chain_link,call_to_receiver`: the default operators don't mutate an `if` or `rescue` that makes up a whole method body.
5. **Check bug fixes against their own revert.** After writing the regression test, run Mutineer on the fixed lines: the mutant that undoes the fix must be killed. If it survives, the test doesn't protect the fix.
6. **Mention accepted survivors in the pull request**, so reviewers can see what's deliberately left unpinned.

Strengthen tests to kill a survivor; don't change code just to make one go away. That applies to coding agents too: the same loop works unattended with `--format json`, whose mutant ids stay stable across edits.

Mutation testing can only exercise code that exists. A missing scope, authorization check or cleanup won't show up as a survivor, so those still depend on review and on authorization tests.

### Database configuration

Fizzy works with SQLite by default and supports MySQL too. You can switch adapters with the `DATABASE_ADAPTER` environment variable. For example, to develop locally against MySQL:

```sh
DATABASE_ADAPTER=mysql bin/setup --reset
DATABASE_ADAPTER=mysql bin/ci
```

The remote CI pipeline will run tests against both SQLite and MySQL.

### Outbound Emails

You can view email previews at http://app.fizzy.localhost:3006/rails/mailers.

You can enable or disable [`letter_opener`](https://github.com/ryanb/letter_opener) to open sent emails automatically with:

```sh
bin/rails dev:email
```

Under the hood, this will create or remove `tmp/email-dev.txt`.

## SaaS gem

37signals bundles Fizzy with [`fizzy-saas`](https://github.com/basecamp/fizzy/tree/main/saas), a companion gem that links Fizzy with our billing system and contains our production setup.

This gem depends on some private git repositories and it is not meant to be used by third parties. But we hope it can serve as inspiration for anyone wanting to run fizzy on their own infrastructure.

