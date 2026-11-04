# Releasing

Work lands on `main` through squash-merged PRs. A GitHub release on `main`
creates the version tag, and GitHub Actions publishes that tag to pub.dev.
The tag starts the publish, never the other way round: publishing (by hand
or by the workflow) doesn't create a tag, and merging a PR doesn't publish.

```
feature branch ──PR (squash)──► main ──GitHub release vX.Y.Z──► tag ──► pub.dev
```

Every release needs a new `version:` in `pubspec.yaml`; pub.dev refuses a
version that was already published.

After the first release, the plan is to add a `develop` branch for
day-to-day work, release by merging `develop` into `main`, and require a
maintainer's approval in the `pub.dev` environment before publishing.

Publishing is safe by construction:

- pub.dev's automated publishing uses GitHub's OIDC token, so there's no
  pub.dev secret stored anywhere.
- pub.dev only accepts publishes from this repository, from tags matching
  `v{{version}}`, and from the `pub.dev` environment.
- The `pub.dev` environment can be limited to `v*` tags and set to wait
  for a maintainer's approval.
- The workflow refuses a tag that isn't on `main` or doesn't match the
  `pubspec.yaml` version, and skips a version that's already on pub.dev.

## One-time setup

1. Publish the first version by hand: `fvm flutter pub publish`.
2. On pub.dev, open the package's **Admin** tab and enable
   **Automated publishing** from GitHub Actions:
   - Repository: `ashiqu-ali/chat_image_editor`
   - Tag pattern: `v{{version}}`
   - Require the GitHub Actions environment: `pub.dev`
3. In the GitHub repository, create an environment named `pub.dev`
   (Settings → Environments), limit it to `v*` tags and, optionally,
   require your approval for it.
4. Tag the hand-published version so git and pub.dev agree: create a GitHub
   release `vX.Y.Z` on the commit you published. The publish workflow runs,
   sees the version is already on pub.dev and stops without publishing.

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

2. Open a PR titled `chore: release X.Y.Z` that:
   - sets `version: X.Y.Z` in `pubspec.yaml`,
   - renames `## [Unreleased]` in `CHANGELOG.md` to `## [X.Y.Z]` and adds a
     fresh empty `## [Unreleased]` above it.

   Squash-merge it into `main`.
3. On GitHub, **Releases → Draft a new release**: target `main`, create the
   tag `vX.Y.Z`, use **Generate release notes** (grouped by PR labels, see
   `.github/release.yml`) and publish the release. Creating the release
   pushes the tag.
4. The **Publish to pub.dev** workflow starts (waiting for your approval
   if the `pub.dev` environment requires it: Actions → the run → **Review
   deployments**), checks that the tag is on `main` and matches the pubspec
   version, and publishes. A few minutes later the version is live on
   pub.dev.
