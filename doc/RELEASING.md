# Releasing

Day-to-day work lands on `develop`. A release merges `develop` into `main`,
then a GitHub release on `main` creates the version tag, and GitHub Actions
publishes that tag to pub.dev after a maintainer approves it.

```
feature branch ──PR──► develop ──release PR──► main ──GitHub release vX.Y.Z──► pub.dev
                 squash                merge commit       tag on main     (approval)
```

Publishing is safe by construction:

- pub.dev's automated publishing uses GitHub's OIDC token, so there's no
  pub.dev secret stored anywhere.
- pub.dev only accepts publishes from this repository, from tags matching
  `v{{version}}`, and from the `pub.dev` environment.
- The `pub.dev` environment only deploys `v*` tags and waits for a
  maintainer's approval.
- The workflow refuses a tag that isn't on `main` or doesn't match the
  `pubspec.yaml` version.

## One-time setup

1. Publish the first version by hand: `fvm flutter pub publish`.
2. On pub.dev, open the package's **Admin** tab and enable
   **Automated publishing** from GitHub Actions:
   - Repository: `ashiqu-ali/chat_image_editor`
   - Tag pattern: `v{{version}}`
   - Require the GitHub Actions environment: `pub.dev`
3. In the GitHub repository, the environment `pub.dev` (Settings →
   Environments) requires a maintainer's approval and only deploys `v*`
   tags.

## Each release

1. Make sure `main` is green. If the UI changed, regenerate the screenshots
   used by the README and pub.dev (from `example/`, with a simulator or
   device running):

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

2. On `develop`, open a PR titled `chore: release X.Y.Z` that:
   - sets `version: X.Y.Z` in `pubspec.yaml`,
   - renames `## [Unreleased]` in `CHANGELOG.md` to `## [X.Y.Z]` and adds a
     fresh empty `## [Unreleased]` above it.

   Squash-merge it into `develop`.
3. Open a PR from `develop` into `main` titled `chore: release X.Y.Z` and
   merge it with **Create a merge commit**, so `main` and `develop` keep the
   same history. Don't squash or rebase this one.
4. On GitHub, **Releases → Draft a new release**: target `main`, create the
   tag `vX.Y.Z`, use **Generate release notes** (grouped by PR labels, see
   `.github/release.yml`) and publish the release. Creating the release
   pushes the tag.
5. The **Publish to pub.dev** workflow starts, waits for your approval in
   the `pub.dev` environment (Actions → the run → **Review deployments**),
   checks that the tag is on `main` and matches the pubspec version, and
   publishes.

A hotfix follows the same path: fix on `develop`, release PR into `main`.
If you ever commit to `main` directly, merge `main` back into `develop`.
