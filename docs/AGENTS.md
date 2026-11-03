# Multi-agent development

This repo is set up so several Claude Code agents can build features in
parallel without stepping on each other.

## Roles

| Agent | File | Owns |
|---|---|---|
| `core-engine` | `.claude/agents/core-engine.md` | geometry, renderers, encoding, export, history, controller + their tests |
| `ui-widgets` | `.claude/agents/ui-widgets.md` | every widget under `lib/src/ui/` + widget tests |
| `example-app` | `.claude/agents/example-app.md` | the example app |
| `docs-writer` | `.claude/agents/docs-writer.md` | README, CHANGELOG, guides |
| `qa-reviewer` | `.claude/agents/qa-reviewer.md` | nothing; reviews and runs checks |

The orchestrator (your main Claude Code session) owns the **contracts**:
models, config, theme, and the public signatures that areas depend on.
Contracts change first, in their own commit, so parallel agents always build
against a fixed API.

## The build-feature workflow

`.claude/workflows/build-feature.js`:

```
Plan ──► Contracts (if needed) ──► Build (parallel, one agent per area)
     ──► Verify (qa-reviewer) ──► Fix (per area) ──► Verify … (max 2 rounds)
```

Ask Claude Code:

> run the build-feature workflow for: add a highlighter pen to the draw tool

You can pass `areas` to limit the work, for example
`{"feature": "…", "areas": ["core", "ui"]}`.

## Rules every agent follows

- Edit only files in its own area (see `CLAUDE.md`).
- Report needed contract changes instead of making them.
- Run `fvm dart format`, `fvm flutter analyze` and the area's tests before
  finishing.
- Never commit; the orchestrator reviews the diff and commits with
  Conventional Commit messages and no AI co-author trailers.
