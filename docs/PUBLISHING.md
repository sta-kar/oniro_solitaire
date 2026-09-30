# Public repository

The GitHub repository starts with a snapshot of the current application source.
The earlier development repository has signing credentials and is retained
separately. Its commit history is not part of the public repository.

## License scope

The project code and original artwork are released under Apache License 2.0.
The adapted Oniro icon on the ace cards comes from an Eclipse Foundation logo
under CC BY 3.0. Its source, license, and modification are recorded in
[`../NOTICE`](../NOTICE) and [`ASSETS.md`](ASSETS.md).

## Local signing

The public `build-profile.json5` selects a `default` signer but contains no
signing credentials. For local development, run `oniro-app sign . --bootstrap`
before `oniro-app build .`.
The sign command generates development signing material and updates
`build-profile.json5` with local passwords. Keep that changed file out of commits
and keep generated material in the ignored `signatures/` directory. Production
distribution requires separately managed signing credentials and profiles.
