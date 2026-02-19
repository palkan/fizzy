# Docker Development: Optional Next Steps

## System Tests (Capybara + Selenium)

Add a Chrome container for running system tests inside Docker.

See: [System of a test: Dockerizing system tests](https://evilmartians.com/chronicles/system-of-a-test-setting-up-end-to-end-rails-testing#dockerizing-system-tests)

## CI with Docker

Create a `compose.ci.yml` override for running `bin/ci` in CI environments (GitHub Actions, etc.).

## Multiple Ruby Versions

Use build args or separate Dockerfiles to test against different Ruby versions.

## Health Checks for Rails

Add a health check to the `web` service so `depends_on` can be used by other services that need Rails to be ready.

## Production-like Setup

Add Thruster/Puma configuration matching production for local performance testing.
