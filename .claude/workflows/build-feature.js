export const meta = {
  name: 'build-feature',
  description: 'Plan a chat_image_editor feature, build it in parallel with role agents, then verify and fix',
  whenToUse: 'Adding or changing a feature that touches one or more areas (core, ui, example, docs) of chat_image_editor.',
  phases: [
    { title: 'Plan', detail: 'split the feature into per-area tasks and contract changes' },
    { title: 'Contracts', detail: 'apply shared API changes before anyone builds on them' },
    { title: 'Build', detail: 'one role agent per area, in parallel, on disjoint files' },
    { title: 'Verify', detail: 'qa-reviewer runs format/analyze/test and reviews the diff' },
    { title: 'Fix', detail: 'area agents fix findings, at most two rounds' },
  ],
}

// Usage: args = "add a highlighter pen"  or
//        args = { feature: "add a highlighter pen", areas: ["core", "ui"] }

const AREAS = {
  core: {
    agentType: 'core-engine',
    paths: 'lib/src/core/**, lib/src/controller/**, test/core/**, test/controller/**',
  },
  ui: { agentType: 'ui-widgets', paths: 'lib/src/ui/**, test/ui/**' },
  example: { agentType: 'example-app', paths: 'example/**' },
  docs: {
    agentType: 'docs-writer',
    paths: 'README.md, CHANGELOG.md, example/README.md, docs/** (not ARCHITECTURE.md or AGENTS.md)',
  },
}
const AREA_KEYS = Object.keys(AREAS)

const input = typeof args === 'string' ? { feature: args } : args || {}
const feature = (input.feature || '').trim()
if (!feature) {
  throw new Error('Pass the feature: args = "..." or { feature: "...", areas: ["core", "ui"] }')
}
const allowedAreas = (input.areas && input.areas.length ? input.areas : AREA_KEYS).filter(
  (a) => AREAS[a],
)

const PLAN_SCHEMA = {
  type: 'object',
  properties: {
    summary: { type: 'string', description: 'One paragraph: what will change and why.' },
    contractChanges: {
      type: 'string',
      description:
        'Exact changes to contract files (models, config, theme, public signatures), or an empty string if none.',
    },
    tasks: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          area: { type: 'string', enum: AREA_KEYS },
          instructions: {
            type: 'string',
            description: 'Self-contained instructions for that area agent, including acceptance criteria and tests.',
          },
        },
        required: ['area', 'instructions'],
      },
    },
  },
  required: ['summary', 'contractChanges', 'tasks'],
}

const REVIEW_SCHEMA = {
  type: 'object',
  properties: {
    passing: { type: 'boolean', description: 'true only if format, analyze and every test pass.' },
    checks: { type: 'string', description: 'Short output summary of each check that ran.' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          area: { type: 'string', enum: AREA_KEYS.concat(['contracts']) },
          file: { type: 'string' },
          line: { type: 'integer' },
          problem: { type: 'string' },
          fix: { type: 'string' },
        },
        required: ['area', 'file', 'problem', 'fix'],
      },
    },
  },
  required: ['passing', 'checks', 'findings'],
}

// ───────────────────────── Plan ─────────────────────────
phase('Plan')
const plan = await agent(
  `You are planning a change to chat_image_editor (a pure-Dart Flutter image editor package).
Read CLAUDE.md and docs/ARCHITECTURE.md, then the code the feature touches.

Feature: ${feature}

Split the work into tasks for these areas only: ${allowedAreas.join(', ')}.
Area ownership:
${allowedAreas.map((a) => `- ${a}: ${AREAS[a].paths}`).join('\n')}

Each task must be doable by its area agent alone, editing only its paths, against a fixed API.
If areas need a new or changed shared API (models, config, theme, controller or core public
signatures, ChatImageEditor widget), describe it precisely in contractChanges; it will be applied
before the build. Omit areas with nothing to do. Do not edit any files.`,
  { agentType: 'Plan', schema: PLAN_SCHEMA, label: 'plan' },
)
if (!plan) throw new Error('Planning failed.')
log(plan.summary)

// ───────────────────────── Contracts ─────────────────────────
if (plan.contractChanges && plan.contractChanges.trim()) {
  phase('Contracts')
  await agent(
    `Apply these contract changes to chat_image_editor, and nothing else:

${plan.contractChanges}

Contract files: lib/src/models/**, lib/src/config/**, lib/src/theme/**, and public signatures in
lib/src/core/**, lib/src/controller/**, lib/src/ui/chat_image_editor.dart, plus exports in
lib/chat_image_editor.dart. New members that need an implementation get a documented signature
whose body throws UnimplementedError; area agents implement them next.
Run \`fvm dart format lib\` and \`fvm flutter analyze\` until clean. Do not commit.`,
    { label: 'contracts' },
  )
}

// ───────────────────────── Build ─────────────────────────
phase('Build')
const byArea = {}
for (const t of plan.tasks || []) {
  if (!allowedAreas.includes(t.area)) continue
  byArea[t.area] = byArea[t.area] ? `${byArea[t.area]}\n\n${t.instructions}` : t.instructions
}
const buildAreas = Object.keys(byArea)
if (!buildAreas.length) {
  log('The plan has no build tasks.')
  return { summary: plan.summary, built: [], passing: null, remaining: [] }
}

function areaPrompt(area, body) {
  return `Feature: ${feature}

Your area: ${area} (${AREAS[area].paths}). Edit only those paths. Other area agents are working in
parallel on their own paths against the same, fixed API.

${body}

Finish by running the checks from your role instructions. Do not commit.`
}

const built = await parallel(
  buildAreas.map((area) => () =>
    agent(areaPrompt(area, byArea[area]), {
      agentType: AREAS[area].agentType,
      phase: 'Build',
      label: `build:${area}`,
    }).then((report) => ({ area, report })),
  ),
)

// ───────────────────────── Verify + Fix ─────────────────────────
async function verify(round) {
  return agent(
    `Review the uncommitted changes in chat_image_editor (\`git diff\` and \`git status\`) for this
feature: ${feature}

Run every check from your role instructions and report real findings only. Mark passing=true only
if format, analyze and all tests pass.`,
    { agentType: 'qa-reviewer', schema: REVIEW_SCHEMA, phase: 'Verify', label: `verify:${round}` },
  )
}

let review = await verify(1)
for (let round = 1; round <= 2; round++) {
  if (!review || (review.passing && !review.findings.length)) break
  const fixable = review.findings.filter((f) => AREAS[f.area])
  if (!fixable.length) break
  const grouped = {}
  for (const f of fixable) (grouped[f.area] = grouped[f.area] || []).push(f)
  log(`Fix round ${round}: ${fixable.length} finding(s) in ${Object.keys(grouped).join(', ')}`)
  await parallel(
    Object.keys(grouped).map((area) => () =>
      agent(
        areaPrompt(
          area,
          `Fix these review findings in your area:\n${grouped[area]
            .map((f) => `- ${f.file}${f.line ? `:${f.line}` : ''}: ${f.problem}\n  Fix: ${f.fix}`)
            .join('\n')}`,
        ),
        { agentType: AREAS[area].agentType, phase: 'Fix', label: `fix:${area}:${round}` },
      ),
    ),
  )
  review = await verify(round + 1)
}

return {
  summary: plan.summary,
  contractChanges: plan.contractChanges,
  built: built.filter(Boolean).map((b) => ({ area: b.area, report: b.report })),
  passing: review ? review.passing : null,
  checks: review ? review.checks : 'verification did not run',
  remaining: review ? review.findings : [],
}
