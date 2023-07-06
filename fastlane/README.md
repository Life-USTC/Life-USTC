fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios generate_new_certificates

```sh
[bundle exec] fastlane ios generate_new_certificates
```

Generate new certificates

### ios build

```sh
[bundle exec] fastlane ios build
```

Build

### ios certificates

```sh
[bundle exec] fastlane ios certificates
```

Get certificates

### ios load_asc_api_key

```sh
[bundle exec] fastlane ios load_asc_api_key
```

Load ASC API Keys

### ios fetch_and_increment_build_number

```sh
[bundle exec] fastlane ios fetch_and_increment_build_number
```

Bump build number based TestFlight

### ios deploy

```sh
[bundle exec] fastlane ios deploy
```

deploy

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
