<!--
Thanks for contributing! A maintainer usually reviews within a week.
The PR title becomes the squash-merge commit, so use Conventional Commits:
  feat(text): add pinch-to-rotate
  fix(crop): keep the frame inside the image after rotating
-->

## What and why

<!-- Describe the change and the reason for it. For UI changes add before/after screenshots. -->

Fixes #<!-- issue number; required unless the change is trivial, like a typo -->

## Checklist

- [ ] I read [CONTRIBUTING.md](../blob/main/CONTRIBUTING.md) and this PR does one thing.
- [ ] The title follows [Conventional Commits](https://www.conventionalcommits.org/).
- [ ] `dart format`, `flutter analyze` and `flutter test` pass locally.
- [ ] I added or updated tests, or explained below why this is test-exempt.
- [ ] I added an entry under **Unreleased** in `CHANGELOG.md` (adding that heading at the top if it isn't there), or explained below why it isn't needed.
- [ ] New or changed public API has `///` doc comments.
- [ ] Breaking changes are called out below with a migration note, or there are none.
- [ ] For performance-sensitive changes, I ran the benchmarks (`flutter test benchmark`) and noted the results.

## Notes for reviewers

<!-- Anything that needs special attention: trade-offs, follow-ups, exemptions. -->
