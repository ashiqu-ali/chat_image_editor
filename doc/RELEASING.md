# Releasing

A maintainer publishes each release to pub.dev by hand from an up-to-date
`main`. Nothing publishes automatically: merging a PR, pushing a tag and
creating a GitHub release don't publish.

```
feature branch ──PR (squash)──► main ──fvm flutter pub publish──► pub.dev
                                  └──tag vX.Y.Z + GitHub release
```

Every release needs a new `version:` in `pubspec.yaml`. pub.dev refuses a
version that was already published, and a published version can't be
deleted (it can only be retracted within 7 days), so check before you
publish.

## Each release

1. If the UI changed, re-record the README GIFs and screenshots with one
   command from the repository root, with an iOS simulator booted
   (`DEVICE=<udid>` picks one; `tool/record_gifs.sh --screenshots --no-gifs`
   refreshes only the screenshots):

   ```bash
   tool/record_gifs.sh --screenshots
   ```

   Or regenerate just the screenshots by hand (from `example/`, with a
   simulator or device running):

   ```bash
   fvm flutter drive --driver=test_driver/screenshot_driver.dart \
     --target=integration_test/screenshots_test.dart -d <device>
   for f in ../doc/screenshots/*.png; do sips -Z 1080 "$f"; done  # macOS
   ```

   The README's preview GIFs live in `doc/gifs/` (`chat.gif`, `draw.gif`,
   `text.gif`, `crop.gif`, `compress.gif`). The README loads them from
   GitHub's raw URLs on `main`, and `.pubignore` keeps them out of the
   published package, so re-record them only when the UI changed and keep
   the file names.

2. Open a PR titled `chore: release X.Y.Z` that:
   - sets `version: X.Y.Z` in `pubspec.yaml`,
   - renames `## [Unreleased]` in `CHANGELOG.md` to `## [X.Y.Z]` and adds a
     fresh empty `## [Unreleased]` above it.

   Squash-merge it into `main`.

3. Check and publish from a clean, up-to-date `main`:

   ```bash
   git switch main && git pull
   fvm dart format --output=none --set-exit-if-changed .
   fvm flutter analyze
   fvm flutter test
   (cd example && fvm flutter analyze && fvm flutter test)
   fvm flutter pub publish --dry-run   # must say "Package has 0 warnings."
   fvm flutter pub publish
   ```

   `pub publish` shows the files it will upload and asks you to confirm.
   The first time, it opens a browser to sign in to pub.dev.

4. Tag the commit you published and create the GitHub release:

   ```bash
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

   Then on GitHub, **Releases → Draft a new release**: choose the tag
   `vX.Y.Z`, use **Generate release notes** (grouped by PR labels, see
   `.github/release.yml`) and publish the release.
