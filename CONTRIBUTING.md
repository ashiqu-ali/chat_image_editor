# Contributing to chat_image_editor

Thanks for taking the time to contribute! This guide explains how to set up the
project and what a good pull request looks like.

## Ground rules

- Be kind. This project follows the [Code of Conduct](CODE_OF_CONDUCT.md).
- Open an issue before starting large changes so we can agree on the approach.
- Keep pull requests focused: one feature or fix per PR.
- Only contribute code you wrote yourself or that is compatible with the
  [MIT License](LICENSE).

## Setup

The project pins its Flutter SDK with [FVM](https://fvm.app). Plain `flutter`
works too if your version satisfies the constraint in `pubspec.yaml`.

```bash
fvm install
fvm flutter pub get
cd example && fvm flutter pub get
```

## Before you open a pull request

Run the same checks CI runs:

```bash
fvm dart format --output=none --set-exit-if-changed .
fvm flutter analyze
fvm flutter test
```

- Add or update tests for every behaviour change.
- Document every public API member with `///` doc comments.
- Update `CHANGELOG.md` under **Unreleased**.
- Don't use language features newer than the minimum Dart SDK in
  `pubspec.yaml` (the analyzer enforces this).

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(text): add pinch-to-rotate for text layers
fix(crop): keep the frame inside the image after rotating
docs: document ExportOptions.maxBytes
```

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the editor is
structured and where new code belongs.

## Reporting bugs and security issues

- Bugs and feature requests: use the GitHub issue templates.
- Security issues: follow [SECURITY.md](SECURITY.md); please don't open a
  public issue.
