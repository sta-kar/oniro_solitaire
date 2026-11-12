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

## F-OH catalog submission

The F-OH Oniro catalog submission uses bundle `com.stakar.solitaire` and version
`1.0.0`. Its record is added to `allAppList.json` in the `f-oh-data` repository,
with `data/com.stakar.solitaire/icon.png` and
`data/com.stakar.solitaire/Solitaire-1.0.0.hap`. The icon is a 512 px rendition
of the approved Four Suits Mark. The package is a signed release build made
with `oniro-app build . --product default --module entry --mode release` from
the existing development checkout. The catalog points back to this source
repository.

For updates, keep the bundle name and signing identity stable, increase the app
version, build a new signed release HAP, and update the catalog record and HAP.

## Oniro App Store release

Releases to the [Oniro App Store](https://store.iparo.app) are built and
published by GitHub Actions, through
[`.github/workflows/oniro-store.yml`](../.github/workflows/oniro-store.yml).
It calls the shared
[`oniro-app-store-actions`](https://github.com/eclipse-oniro4openharmony/oniro-app-store-actions)
workflow, which builds the HAP from the tagged commit, attaches it to a GitHub
release, and registers it with the store. Versions published this way carry
the store's *Built from source* badge. No secrets are stored in this
repository: the store checks GitHub's OIDC token instead.

To release:

1. Increase `versionCode` (and `versionName`) in `AppScope/app.json5`. The
   store accepts only a `versionCode` higher than the last published one.
2. Commit and push to `main`.
3. Tag the commit and push the tag, for example
   `git tag v1.0.1 && git push origin v1.0.1`.

The CI build signs with the OpenHarmony SDK's development key, the same key
that signed version 1.0.0, so installed copies update in place. Version 1.0.0
was uploaded by hand. The first release from this repository links the store
listing to it, and from then on the app can be published by CI only from here.
