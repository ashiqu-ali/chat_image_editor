# Releasing

Releases are cut from `main` by a maintainer and published to pub.dev by
GitHub Actions when a version tag is pushed.

## One-time setup

1. Publish the first version by hand: `fvm flutter pub publish`.
2. On pub.dev, open the package's **Admin** tab and enable
   **Automated publishing** from GitHub Actions:
   - Repository: `ashiqu-ali/chat_image_editor`
   - Tag pattern: `v{{version}}`
   - Require the GitHub Actions environment: `pub.dev`
3. In the GitHub repository, create an environment named `pub.dev`
   (Settings → Environments) and, optionally, require your approval for it.

## Each release

1. Make sure `main` is green. If the UI changed, regenerate the screenshots
   used by the README and pub.dev (from `example/`, with a simulator or
   device running):

   ```bash
   fvm flutter drive --driver=test_driver/screenshot_driver.dart \
     --target=integration_test/screenshots_test.dart -d <device>
   for f in ../doc/screenshots/*.png; do sips -Z 1080 "$f"; done  # macOS
   ```

2. Open a PR titled `chore: release X.Y.Z` that:
   - sets `version: X.Y.Z` in `pubspec.yaml`,
   - renames `## [Unreleased]` in `CHANGELOG.md` to `## [X.Y.Z]` and adds a
     fresh empty `## [Unreleased]` above it.
3. Merge it, then tag the merge commit:

   ```bash
   git switch main && git pull
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

4. The **Publish to pub.dev** workflow checks that the tag matches the
   pubspec version and publishes.
5. Create a GitHub release from the tag and use **Generate release notes**;
   they're grouped by PR labels (see `.github/release.yml`).
