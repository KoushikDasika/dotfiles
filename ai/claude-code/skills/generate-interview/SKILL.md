---
name: generate-interview
description: Design and generate technical interview exercises from the current codebase. Produces two exercises (online assessment + take-home refactor), interviewer rubrics, answer keys, and a Google Sheets scoring spreadsheet.
when_to_use: "generate interview", "create interview exercise", "build interview challenge", "design hiring assessment", "make interview exercises"
argument-hint: "[role-title]"
allowed-tools: Read Bash(ls *) Bash(find *) Bash(grep *) Bash(cat *) Bash(rtk *) Bash(mkdir *) Write Edit
---

# Generate Interview Exercises

You are a master technical interviewer. Your job: distill the current codebase's core domain into
two interview exercises that also serve as onboarding material for new hires. You will interview
the user, explore the codebase, collaboratively design exercises, then generate implementable
prompt files and a scoring rubric.

**Role provided:** $ARGUMENTS

---

## Phase 1 — Intake Interview

Ask the user these questions using AskUserQuestion. Do not skip this phase.

**Question set 1:**
- Role title and seniority level (if not provided via $ARGUMENTS)
- Primary language(s) for the exercises (e.g. Elixir, TypeScript, Python, Go)
- Which exercises to generate: Exercise 1 (online assessment), Exercise 2 (take-home), or both

**Question set 2 (if Exercise 2 selected):**
- Time box (default 45 min)
- Exercise 2 format:
  - **Refactor-only**: code works, tests pass; candidate spots anti-patterns and refactors
  - **Fix-then-refactor**: fat controller, failing tests from real bugs; candidate fixes then refactors
  - **Debug-a-broken-app**: planted bugs across layers; candidate debugs, fixes, then improves

---

## Phase 2 — Codebase Exploration

Launch up to 3 Explore agents in parallel to map the codebase. Each agent should investigate:

**Agent 1 — Core domain:**
- What does this app do? (README, mix.exs/package.json/go.mod, top-level lib/src structure)
- What is the core domain? (main schemas/models, contexts/services, database tables)
- What are the 2-3 most important/interesting pieces of business logic?
- What patterns repeat? (contexts, services, workers, pub/sub, etc.)

**Agent 2 — Pure function candidates + testing:**
- Find non-trivial pure functions: transforms, matchers, normalizers, validators, key generators,
  scoring functions, parsers — anything testable without a database
- Identify 3-5 candidates for "1-2 functions with tests" distillation
- How are tests written? (framework, fixtures/factories, test support modules)

**Agent 3 — Existing interview repos + feature candidates:**
- Look in sibling directories for existing interview challenge repos (patterns: `*interview*`,
  `*challenge*`, `*assessment*`)
- Identify 2-3 features that could be simplified into a fat controller exercise
- Look for real production bugs/incidents in recent commits that make good planted bugs

Present findings to the user as a structured options menu before proceeding.

---

## Phase 3 — Exercise Design (Collaborative)

Present options and let the user choose. Use AskUserQuestion for each decision.

### For Exercise 1 (Online Assessment)

Propose 2-3 options for each part:

**Part 1 — Writing sample topic:** Propose concepts from the codebase that a senior engineer
should be able to explain to a junior. Good candidates: fuzzy matching, content-hash dedup,
idempotency, eventual consistency, rate limiting, caching invalidation, etc.

**Writing sample design rule:** The candidate-facing question must pose a SCENARIO + a naive
approach + ONE open-ended ask: "explain why this is insufficient and what you would do instead.
Include the failure modes and the tradeoffs of your proposed approach."
It must NOT list sub-questions, name specific techniques, or hint at the expected answer.
Asking for "failure modes and tradeoffs" is fine — that's what senior engineers DO. But naming
WHICH failure modes or WHICH tradeoffs (e.g. "discuss precision/recall", "mention normalization")
gives away the answer. The rubric (interviewer-only) lists what to score for — but the question
stays open-ended so you see what the candidate comes up with unprompted.

**Part 2 — ERD/systems design:** Propose the minimal set of seed entities that frame the domain
problem without solving it. Give enough to define the problem space (e.g. `Source`, `Event`,
`Venue` for a ticketing domain; or `Provider`, `Patient`, `Appointment` for healthcare). The
number of seeds depends on the domain — could be 2, could be 4 — but they should be the
top-level domain nouns, NOT the derived/intermediate entities the candidate needs to design.

**ERD design rule:** Provide only seed entities with a one-line description each (no field lists).
The candidate must independently design: any intermediate/derived entities (per-source records,
canonical records, link/match/junction tables), all fields/columns, relationships, cardinality,
dedup mechanisms, and indexes. The interviewer rubric scores whether they arrive at the right
structures on their own. Do NOT give away derived entities, join tables, `dedup_key` fields,
or column lists — those are the answer, not the question.

**Part 3 — Code sample function:** Propose 2-3 pure-function candidates from the codebase.
The function must have a **tiered seniority gradient** — naive approaches pass basic tests,
sophisticated approaches pass all. The test suite is organized in explicit tiers.

**Part 3 design rule — tiered tests, not binary pass/fail:**
The code challenge must NOT be a regex exercise, CRUD boilerplate, or leetcode puzzle. These
produce binary outcomes (you know it or you don't) with no seniority gradient.

Instead, choose functions where the APPROACH reveals depth:
- **Tier 1 (any dev):** Exact equality, simple cases → basic tests pass
- **Tier 2 (competent):** Case handling, proximity/tolerance logic → intermediate tests pass
- **Tier 3 (strong):** Tokenized/fuzzy comparison, weighted scoring, continuous vs binary → advanced tests pass
- **Tier 4 (senior):** nil handling, edge cases, defensive coding → expert tests pass

Good candidates: **similarity scorers** (compare two records across dimensions, return float scores),
**match rankers** (rank candidates by multi-dimension similarity), **conflict resolvers** (merge
overlapping records with precedence rules), **data quality validators** (score record completeness
with configurable rules).

Bad candidates: regex normalization (binary), hash key generators (trivial once you know phash2),
string formatters (mechanical), CRUD serializers (no gradient).

The candidate-facing README should say "make as many tests pass as you can" — NOT "make all
tests pass." This signals that partial credit exists and reduces pressure to skip hard tiers.

### For Exercise 2 (Tech Panel)

**Feature selection:** Propose 2-3 features from the codebase that can be simplified into a
single fat controller. Good candidates: any CRUD + processing pipeline (ingest, order processing,
ranking calc, report generation).

**Broken test / planted bug:** Propose 2-3 bugs to plant. Draw from:
- Race conditions (concurrent upsert without unique constraint)
- Missing transaction wrappers
- N+1 queries
- Missing filter clauses
- Non-deterministic ordering

**Code smell inventory:** Identify 6+ smells to plant. Draw from:
- Duplicated parsing/formatting logic
- Raw table strings instead of schema modules
- Inline response-map construction (should be view module)
- Controller doing data access (should be context)
- Dead assignments
- Magic strings

---

## Phase 4 — Generate Deliverables

Create an `interview/` directory in the project root and generate the following files.

### Exercise 1 — `interview/exercise-1-online-assessment.prompt.md`

This is a **prompt for the recruiter or an external LLM** to generate the actual assessment.
The recruiter has NO access to the codebase. All candidate-facing content MUST use
**industry-standard generic terminology** — never internal schema names, module names, or
domain jargon.

Structure the prompt file with these sections:

```
# Prompt: Build Exercise 1 — Online Assessment

## Context
- Role, seniority, language
- What this prompt produces (4 markdown files + standalone code project)
- "Use industry-standard generic terminology throughout. Do not reference internal names."

## What you will produce
- part1_writing_prompt.md (candidate-facing)
- part2_erd_prompt.md (candidate-facing)
- part3_code_project.md (candidate-facing README)
- The standalone code project directory (stubbed functions + full test suite)

NOTE: The interviewer rubric is a SEPARATE deliverable — it lives in a Google Sheet and/or
a local markdown file generated by the skill, NOT inside this prompt. The Ropes.ai prompt
output must NEVER contain the grading rubric, reference solutions, or scoring criteria.
Those go to interviewers through a separate channel.

## Part 1 — Writing Sample
- Full candidate-facing question text
- Present the SCENARIO and the junior dev's naive suggestion
- Ask ONE open-ended question: "explain why this is insufficient and what you would do instead.
  Include the failure modes and the tradeoffs of your proposed approach."
- DO NOT add sub-questions or hints that name WHICH failure modes or WHICH tradeoffs
  (e.g. "discuss normalization", "mention similarity algorithms", "explain precision/recall").
  Asking for "failure modes and tradeoffs" generically is fine — that's what senior engineers DO.
  But naming them gives away the answer. The question poses the PROBLEM; the candidate
  provides the ANSWER.
- The INTERVIEWER RUBRIC (not seen by candidate) lists what to score for (normalization,
  approximate matching, tradeoff awareness, etc.) — but the question itself must not hint.
- "In a few sentences or paragraphs" — no word count. "No code required."

## Part 2 — ERD / Systems Design
- Context paragraph (what the system does, in generic terms)
- Provide only the minimal seed entities that frame the domain (top-level nouns, one-line
  description each, no field lists). Number depends on domain — as few as needed, no more.
- Do NOT provide derived entities, join tables, field lists, dedup mechanisms, or column names
- Task: design additional entities needed, their fields/columns, relationships, cardinality, indexes,
  and the flow for a new incoming record
- The candidate must independently arrive at any intermediate structures, link tables, dedup keys, etc.
- "You may use diagram tools, ASCII art, or prose"

## Part 3 — Code Sample
- Candidate-facing README: "make as many tests pass as you can" (NOT "make all tests pass")
- Project setup instructions (language-specific: mix test / npm test / go test / etc.)
- ONE function signature with doc comments (stubbed with raise/throw)
- Test suite organized in explicit tiers (Tier 1: basics, Tier 2: competent, Tier 3: strong, Tier 4: senior)
- Each tier should be a separate `describe` block so progress is visible in test output
- "Do not modify the test file. You may use Google/AI assistants."
- "Make sure you have access to the language's developer docs" — include the relevant docs URL
  (e.g. hexdocs.pm/elixir, docs.python.org, devdocs.io, etc.)
- The function should be a SCORING or COMPARISON function (not regex, not CRUD, not leetcode)
  where naive approaches (exact equality) pass Tier 1, and sophisticated approaches (tokenized
  comparison, decay curves, nil handling) pass higher tiers

```

**CRITICAL RULES for Exercise 1:**
- The Ropes.ai prompt output must NEVER include the grading rubric, reference solutions, scoring
  criteria, answer keys, or any interviewer-only material. The recruiter generating the assessment
  from this prompt should not see how it's scored. The rubric is a separate deliverable generated
  by the skill as a Google Sheet and/or a standalone `interview/exercise-1-rubric.md` file.
- Parts 2 and 3 must not leak into each other. Part 2 grades data model design; Part 3 grades
  function implementation. Keep them disjoint.
- All candidate-facing text uses generic terms. Map internal names to generic equivalents in
  a separate interviewer reference (NOT in the Ropes prompt).

### Exercise 2 — `interview/exercise-2-refactor-challenge.prompt.md`

This is a **prompt for an LLM to generate the actual exercise repo**. It IS codebase-specific.

**CRITICAL RULE — No answer giveaways in candidate-facing code:**
The generated exercise code must NOT contain any comments, markers, or labels that point
candidates to bugs, smells, or incomplete work. Specifically:
- NO `// FAILING TEST:` or `# FAILING TEST:` banners
- NO `// BUG:`, `// SMELL:`, `// FIXME:`, `// HACK:` markers on planted problems
- NO `assert false` or `TODO` stub tests — stub tests must have realistic names and
  assertions that fail because the feature is genuinely broken or unimplemented
- NO `// pre-commented anti-pattern` labels
- NO comments explaining what's wrong with the code the candidate is supposed to fix

Bugs should cause real test failures. Smells should look like real production code written
by a busy developer. The candidate's job is to run the tests, read the error output,
locate the problems, and fix them. Labeling the problems in the code defeats the purpose
of the exercise.

The ANSWER_KEY.md and GRADING_RUBRIC.md (interviewer-only, never shared with candidates)
are where all planted problems are documented with locations and explanations.

Structure the prompt file to produce a complete, runnable project. Reference these existing
exercise repos as structural templates (describe their key patterns):

**Reference repos (describe structure, don't require access):**
- `b2b_elixir_interview_challenge` — Elixir/Phoenix fat controller, fix-then-refactor. Single
  `ranking_controller.ex` with all logic inline, raw table strings, duplicated patterns.
  README: Overview → Setup (docker compose) → Exercise (Current State / Your Task / Rules) → API.
  Tests: ConnCase, insert helpers. 45-min box.
- `payments_interview_assessment` — TypeScript/Express+Prisma single `billPaymentController.ts`.
  Failing tests for race condition + idempotency bugs. Docker compose + postgres.
- `b2b_fullstack_interview_challenge` — Elixir+React debug-a-broken-app. Planted bugs across
  backend (missing date filter) and frontend (malformed URL, missing useMemo). 10x5=50pt rubric.
- `interview_assessment/connection_pool` — Elixir/OTP refactor-only. Anti-patterns embedded
  naturally in the code (not labeled). 45-min box. 100pt rubric with bonus.

Structure the prompt:

```
# Prompt: Build Exercise 2 — [Feature] Refactor Challenge

## Context
- Role, language, framework version, exercise format (refactor-only / fix-then-refactor / debug)
- Reference repo to mirror (describe its structure)

## What you will produce
- Complete runnable project directory structure
- README.md (candidate-facing, house structure)
- GRADING_RUBRIC.md (interviewer-only)
- ANSWER_KEY.md (interviewer-only, pre-filled bug + smell tables)
- SOLUTION.md (interviewer-only, full reference fix + refactor)
- Docker setup (app + db services)

## README framing
Overview ("all logic in a single fat controller") → Setup (docker compose) →
Exercise (Current State → Your Task: 1. separation of concerns, 2. improve code) →
Rules (tests pass, don't change response format, time box) → API endpoint spec tables

## Domain and schemas
- What the simplified app does
- Schema definitions (provided but unused in controller — raw table strings)
- Migrations (deliberately missing constraints = seams for broken tests)

## The fat controller
- Full logic specification for each action
- PLANTED ANTI-PATTERNS: list each bug and smell for the generating LLM to embed
  naturally in the code. The bugs/smells must look like real production code — NO
  comment markers, NO `// BUG:`, NO `// SMELL:`, NO `// FIXME:`, NO `# TODO:`.
  The candidate discovers problems by running tests, reading code, and debugging.
  [list each planted bug and smell with what it should look like in the code]

## Test suite
- All passing tests enumerated
- Broken tests that fail due to genuine bugs in the code (no banner comments, no labels,
  no hints pointing the candidate to the problem — they must run the tests, read the
  failures, and debug)
- Any stub tests should use a realistic test name and assertion — not `assert false` or
  a `TODO` comment. The test should look like a real test that fails because the
  underlying feature is unimplemented or broken

## GRADING_RUBRIC.md
- Banner: "For interviewer use only — do not share with candidates"
- Scoring grid: N topics × 5pts each
  [list each rubric topic with its description]
- Bonus rows (0 base pts): "Identifies subtle bugs", "Points out code smells"
- Score = total / max × 100%
- Interviewer notes template

## ANSWER_KEY.md
- Banner: "For interviewer use only — do not share with candidates"
- Bugs table: # | Issue Title | Line Range | Severity | Status | Recommended Action
  [pre-fill with all planted bugs]
- Code Smells table: # | Title | Location | Severity | Duplication Count | Refactoring Suggestion
  [pre-fill with all planted smells]

## SOLUTION.md
- Banner: "For interviewer use only — do not share with candidates"
- Full reference solution (fix + refactor)
- Must make ALL tests pass including the race test

## Verification
- mix test / npm test must show exactly N failing tests on starting code
- SOLUTION.md branch makes all green
- Confirm failure is deterministic, not a flake
```

### Google Sheets Scoring Rubric

After generating the prompt files, create a Google Sheet rubric via Drive MCP.

**CRITICAL: Match the exact style of the existing rubric sheets.** Before generating, read both
reference sheets using Google Drive MCP to match their exact layout, column structure, and format:

- **Scoring tab reference:** https://docs.google.com/spreadsheets/d/1F9YaeaZ1ntCnYiEpWD0wcByBbrYk97EyOC3cvPqFcGA/edit?gid=629686356#gid=629686356
- **Extra Credit tab reference:** https://docs.google.com/spreadsheets/d/1F9YaeaZ1ntCnYiEpWD0wcByBbrYk97EyOC3cvPqFcGA/edit?gid=1873640917#gid=1873640917

Read these sheets (file ID: `1F9YaeaZ1ntCnYiEpWD0wcByBbrYk97EyOC3cvPqFcGA`) via
`mcp__claude_ai_Google_Drive__read_file_content` to capture the exact column layout, row
structure, header formatting, and scoring formulas before generating the new rubric. The new
sheet must look like it belongs in the same family as the existing ones — same column order,
same row types, same formula patterns, same bonus/total/score-% row structure.

**Main Scoring Sheet** — create via `mcp__claude_ai_Google_Drive__create_file` with:
- Title: `"[Team] [Role] Technical Exercise (Scoring)"`
- Content: CSV matching the reference sheet structure exactly:
  - Row 1: column headers (Topics, Total Points/Topic, then 5+ empty candidate columns)
  - Topic rows: each with description in column A, `5` in column B, `0` in candidate columns
  - `Extra Credit,0` row and `Bonus - Code Smells,0` row
  - `Total,[sum]` row and `Score,0.00%` row
- contentMimeType: `text/csv` (auto-converts to Google Sheet)

**Extra Credit Sheet** — create a second Google Sheet with:
- Title: same + `" - Extra Credit"`
- Two sections matching the reference Extra Credit tab exactly:
  - **Bugs table:** Column 1 | Issue Title | Line Range | Severity | Status | Recommended Action
  - **Code Smells table:** ID | Code Smell Title | Location (Lines) | Severity Estimate | Duplication Count | Refactoring Suggestion
- Pre-filled with the planted items from the answer key
- contentMimeType: `text/csv`

If Google Drive MCP is unavailable, fall back to writing CSV files locally at
`interview/rubric-scoring.csv` and `interview/rubric-extra-credit.csv` and tell the user
to import them into Google Sheets.

Share the Google Sheet URLs with the user when done.

---

## Rubric Topic Pools

When designing the rubric, draw N topics (typically 8-10) from these pools. Every rubric
MUST include at least one topic from each pool.

### Domain-specific finds (select based on planted problems)
- Bug identification — one row per planted bug with full description
- Anti-pattern identification — one row per planted anti-pattern
- Schema/architecture awareness — "Uses provided schema modules instead of raw table strings"

### Refactoring skills (select based on exercise type)
- Context Extraction — "Moves business logic out of controller into a context module"
- Controller Thinning — "Controller actions become thin: parse params, call context, render"
- JSON View / Response Formatting — "Extracts repeated inline response maps to a view module"
- DRY / Duplication — "Consolidates repeated patterns (list specific duplications and counts)"
- Type Safety — "Replaces local type definitions with existing shared types"
- Component Composition — "Extracts repeated UI patterns into reusable components" (frontend)
- API Isolation — "Tested the API layer directly to confirm where the bug lives"

### Process skills (always include all of these)
- Testing — "Ran tests without prompting; wrote additional tests to cover gaps"
- Communication — "Thought aloud, explained reasoning, asked clarifying questions"
- Code Quality — "Fixes are minimal, targeted, consistent with surrounding code"
- Debugging Process — "Used right tools at right layer before touching code"
- Language Readability — "Can navigate unfamiliar code in the stack" (only if cross-stack role)

---

## Interview Best Practices (encode in all generated rubrics)

### What great interviewers do
- Let the candidate drive. Only redirect if they're stuck for >3 minutes.
- "How would you test this?" is a better probe than "Did you run the tests?"
- Score what you observe, not what you infer. "Didn't mention X" ≠ "Doesn't know X."
- Take timestamped notes during the exercise for the debrief.

### Interviewer notes template (include in every GRADING_RUBRIC.md)
```
**Candidate:**
**Date:**
**Interviewer(s):**
**Exercise version:**

**Time management:**
**Questions asked:**
**Approach taken (read first / dive in / etc.):**
**Notable insights:**
**Areas of strength:**
**Areas for growth:**
**Hire recommendation:**
```

### Score interpretation bands (calibrate per exercise)
The generating LLM should set bands relative to the max score:
- **Strong hire**: ≥85% — deep understanding + clean execution
- **Hire**: 70-84% — solid fundamentals, minor gaps
- **Maybe**: 55-69% — shows promise, needs development
- **No hire**: <55% — significant gaps

---

## Output Summary

When all deliverables are generated, present the user with:

1. File paths for both prompt files
2. Google Sheet URLs for the scoring rubrics (or CSV paths if Drive unavailable)
3. Next steps: "Feed each prompt file to a capable LLM to implement the actual exercise repos.
   Spot-check that tests fail on stubs/starting-code and pass on the reference solution."
4. Reminder: "The Exercise 1 prompt is designed for a recruiter or external tool with no codebase
   access. The Exercise 2 prompt is designed for an LLM with access to generate the repo."
