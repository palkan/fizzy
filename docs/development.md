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
bin/mutineer app/models/card.rb                  # one file, against its paired test
bin/mutineer app/models --since origin/main      # only the lines changed on your branch
bin/mutineer app/models --no-fail-fast           # every survivor in a directory
```

Each source runs against its conventionally paired test (`app/models/card.rb` with `test/models/card_test.rb`); pass `--test FILE` to add others. Mutineer only mutates method bodies, so scopes, callbacks and associations declared in class bodies aren't covered. Settings live in `.mutineer.yml`, and `test/mutineer_boot.rb` adapts the app to how Mutineer loads mutants.

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

