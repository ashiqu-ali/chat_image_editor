# Contributing to chat_image_editor

Thanks for taking the time to contribute! This guide explains how to set up
the project and how pull requests move from idea to release.

## Ground rules

- Be kind. This project follows the [Code of Conduct](CODE_OF_CONDUCT.md).
- Start from an issue. For anything bigger than a small fix, agree on the
  approach in the issue before writing code.
- One pull request does one thing.
- Only contribute code you wrote yourself or that is compatible with the
  [MIT License](LICENSE).

## Setup

The project pins its Flutter SDK with [FVM](https://fvm.app) (see `.fvmrc`).
Plain `flutter` works too if your version satisfies `pubspec.yaml`.

```bash
fvm install
fvm flutter pub get
cd example && fvm flutter pub get
```

## Checks

Run what CI runs before you push:

```bash
fvm dart format .
fvm flutter analyze
fvm flutter test
cd example && fvm flutter analyze && fvm flutter test
```

For performance-sensitive changes also run the benchmarks; see
[doc/PERFORMANCE.md](doc/PERFORMANCE.md).

## Code style

- Follow [Effective Dart](https://dart.dev/effective-dart) and the lints in
  `analysis_options.yaml`.
- Every public member has a `///` doc comment.
- Don't use language features newer than the minimum Dart SDK in
  `pubspec.yaml`; the minimum-Flutter CI job catches this.
- Widgets never hard-code colors, icons or user-facing strings; they come
  from the theme, icon and string classes so apps can customize them.
- See [doc/ARCHITECTURE.md](doc/ARCHITECTURE.md) for where code belongs.

## How pull requests are handled

### 1. Open the PR

- Branch from `main`.
- Write the title as a [Conventional Commit](https://www.conventionalcommits.org/),
  e.g. `feat(text): add pinch-to-rotate`. PRs are squash-merged, so the title
  becomes the commit on `main`.
- Fill in the template: what and why, the issue it fixes
  (`Fixes #123`), and the checklist.
- UI changes include before/after screenshots.

### 2. Automated checks

Every PR runs:

| Check | What it enforces |
|---|---|
| **CI / Format, analyze and test** | formatting, analyzer, all tests, coverage report, example app |
| **CI / Minimum supported Flutter** | the package still analyzes on the oldest supported SDK |
| **CI / Benchmarks** | reports export and encoding timings (informational) |
| **CI / Pub score and publish dry run** | pub.dev score and a valid package |
| **PR checks / Conventional title** | the title format |
| **PR checks / Tests and CHANGELOG** | changes to `lib/` come with tests and a `CHANGELOG.md` entry |

A bot labels the PR by the areas it touches (`p: core`, `p: ui`,
`p: theming`, `a: api`, `a: performance`, `example`, `docs`, `ci`).

### 3. Exemptions

Some changes legitimately don't need tests or a changelog entry, such as
pure refactors, comment fixes or tooling changes. Explain why in the PR
and a maintainer adds `test-exempt` or `changelog-exempt`. Only maintainers
add these labels.

### 4. Review

- A code owner reviews every PR (see `.github/CODEOWNERS`).
- Address feedback with new commits instead of force-pushing, so reviewers
  can see what changed since their last pass. The squash merge cleans it up.
- Resolve a conversation only when the reviewer's point is addressed.
- If we ask for more information and don't hear back for 14 days, the PR
  is marked `no response` and closes 7 days later. You can always reopen.

### 5. Merge

A maintainer squash-merges once checks pass and the review is approved.
The PR's labels decide where it appears in the release notes.

## Breaking changes

- Avoid them when you can: add the new API, deprecate the old one with
  `@Deprecated('Use X instead. Deprecated in 0.3.0.')`, and remove it in a
  later minor release (before 1.0) or major release (after 1.0).
- Label the PR `breaking-change` and add a migration note to the
  `CHANGELOG.md` entry.

## Versioning and releases

The package follows [semantic versioning](https://dart.dev/tools/pub/versioning).
Before 1.0, breaking changes bump the minor version (`0.1.x` → `0.2.0`).
Maintainers release from `main`; see [doc/RELEASING.md](doc/RELEASING.md).

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/):

```
feat(text): add pinch-to-rotate for text layers
fix(crop): keep the frame inside the image after rotating
perf(export): skip re-encoding when the image already fits maxBytes
docs: document ExportOptions.maxBytes
```

## Reporting bugs and security issues

- Bugs, feature ideas and performance problems: use the issue templates.
- Security issues: follow [SECURITY.md](SECURITY.md); please don't open a
  public issue.
