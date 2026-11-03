# CLAUDE.md

Guidance for AI coding agents working in this repository.

## Project

`chat_image_editor` is an open-source (MIT), pure-Dart Flutter package: a
lightweight, WhatsApp-style image editor for chat apps (draw, text, crop,
rotate, flip, compress, caption, send). **Static images only**; no GIF,
video or animation support.

Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) before changing code.

## Commands

The SDK is pinned with FVM. Always prefix with `fvm`.

```bash
fvm flutter pub get
fvm dart format .
fvm flutter analyze
fvm flutter test
cd example && fvm flutter run
```

## Ownership map

| Area | Paths | Role agent |
|---|---|---|
| Contracts | `lib/src/models/`, `lib/src/config/`, `lib/src/theme/`, public signatures in `lib/src/core/`, `lib/src/controller/`, `lib/src/ui/chat_image_editor.dart` | orchestrator only |
| Core engine | `lib/src/core/**`, `lib/src/controller/**`, `test/core/**`, `test/controller/**` | `core-engine` |
| UI | `lib/src/ui/**`, `test/ui/**` | `ui-widgets` |
| Example app | `example/**` | `example-app` |
| Docs | `README.md`, `CHANGELOG.md`, `docs/**` (except this file's rules) | `docs-writer` |
| Review | read-only everywhere | `qa-reviewer` |

Stay inside your area. If you need a contract change, stop and report it;
don't edit contract files from a role agent.

## Code rules

- Pure Dart in `lib/`: no platform plugins, no `dart:io`, no
  `package:flutter/services.dart` platform channels beyond haptics/clipboard.
- New runtime dependencies need maintainer approval. Today: only `image`.
- Don't use language features newer than the minimum SDK (`^3.8.0`), e.g. no
  dot shorthands. The analyzer enforces this.
- Every public member gets a `///` doc comment (`public_member_api_docs`).
- Models are immutable; state changes go through `ChatImageEditorController`.
- Widgets never hard-code colors, icons or strings; read them from
  `ChatImageEditorScope.of(context)`.
- Geometry only in `ImageGeometry`; painting only in `lib/src/core/render/`.
- Add or update tests with every behaviour change.

## Clean-room rule

Only original code. Never paste code, assets or text from other projects or
proprietary sources. Other products may be named only in prose as
"WhatsApp-style", alongside the non-affiliation disclaimer in the README.

## Commits

- Conventional Commits: `feat(text): …`, `fix(crop): …`, `docs: …`.
- **Never add `Co-Authored-By` or any AI attribution trailer.**
- Role agents don't commit. The orchestrating session reviews and commits.
- Don't change git config.

## Multi-agent workflow

Role agents live in `.claude/agents/`. The saved workflow
`.claude/workflows/build-feature.js` orchestrates them:

1. **Plan**: splits a feature into per-area tasks and any contract changes.
2. **Contracts**: applies contract changes first, if needed.
3. **Build**: area agents work in parallel on disjoint files.
4. **Verify**: `qa-reviewer` runs format/analyze/test and reviews the diff.
5. **Fix**: area agents fix findings (up to two rounds).

Run it from Claude Code with: "run the build-feature workflow for: <feature>".
See [docs/AGENTS.md](docs/AGENTS.md).
