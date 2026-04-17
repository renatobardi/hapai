# Product Requirements Document: Ensi — BMAD Method for Multica

**Date:** 2026-04-17
**Author:** PM Agent (BMAD pipeline)
**Status:** Draft — awaiting Architect review
**Input:** `_bmad/docs/product-brief.md` (Analyst, 2026-04-17)

---

## 1. Product Overview

### Vision
Ensi is an ACP-compatible agent that brings the proven BMAD planning methodology (Analyst → PM → Architect) into the Multica workspace as autonomous teammates, eliminating the gap between ideation and implementation for teams using managed AI agents.

### Problem Summary
Teams on Multica skip structured planning and jump straight to coding agents, causing rework, scope creep, and missed requirements. BMad Method (45k+ stars) has the methodology but is CLI-only and stateless. Multica has the platform but no planning layer. Ensi bridges them via ACP.

### Target Users
- **Marco** — Solo developer, Multica user. Wants a structured brief before assigning coding issues.
- **Ana** — Tech lead on a team of 3–5. Needs consistent planning artefacts for sprint planning and team review.
- **James** — BMad Method power user. Wants session persistence and team visibility without the CLI.

---

## 2. Validation Spikes (Pre-Story Gates)

> **These two spikes must be completed and pass before user story implementation begins.** They de-risk the two highest-impact assumptions in the product brief. If either spike fails, scope must be renegotiated before committing to the full build.

### Spike 1 — ACP + Multica Daemon Integration (SP-01)

**Goal:** Prove that an ACP-compatible TypeScript agent can register with the Multica daemon, receive a task, and post a response — end-to-end — without a custom fork of Multica.

**Done when:**
- A minimal "hello world" ACP agent (< 50 LOC) registers with the local Multica daemon
- The agent receives a task payload sent via `multica` CLI
- The agent posts a comment back to the triggering issue
- No daemon fork, monkey-patching, or undocumented APIs required
- ACP SDK version is pinned; adapter layer is defined

**Fail criteria:** If registration or message exchange requires changes to the Multica daemon source, stop and escalate. The full build is not viable without a first-class ACP integration path.

**Estimated effort:** S (1–2 days)

---

### Spike 2 — BMad Prompt Portability (SP-02)

**Goal:** Confirm that the core BMad Analyst, PM, and Architect prompts produce useful, structured output when invoked via the Anthropic API directly — without an IDE, without a CLAUDE.md context file, and without human guidance during generation.

**Done when:**
- Analyst prompt produces a product-brief.md that passes a human quality bar (coherent, specific, not generic)
- PM prompt consumes the brief and produces a PRD with testable user stories
- Architect prompt consumes the PRD and produces an ADR with actionable stack choices
- All three prompts run without modification to the core BMad prompt text (adapt wrapping, not content)
- Output quality is rated ≥ 4/5 by a developer unfamiliar with the project under test

**Fail criteria:** If prompts require substantial rewriting to work without IDE context, the prompt-porting effort must be scoped as a separate workstream before the full build. If output quality is < 3/5, the BMad methodology assumption does not hold and the product strategy must be revisited.

**Estimated effort:** S (1–2 days)

---

## 3. Functional Requirements

### Agent Protocol & Platform Integration

| ID | Requirement |
|----|-------------|
| FR-01 | The system must expose an ACP-compatible agent interface that the Multica daemon can discover and register automatically. |
| FR-02 | The system must receive task payloads from the Multica daemon when a Multica issue is tagged `BP` (Brainstorm/Planning). |
| FR-03 | The system must post structured comments to the triggering Multica issue at stage completion, stage failure, and when awaiting human input. |
| FR-04 | The system must update the Multica issue status to reflect pipeline state (e.g., `in_progress` during a stage, `in_review` when awaiting human approval). |

### Planning Pipeline

| ID | Requirement |
|----|-------------|
| FR-05 | The system must execute the Analyst stage first, producing `product-brief.md` in `.ensi/docs/` within the checked-out project repository. |
| FR-06 | The system must execute the PM stage after the Analyst stage completes (and human approval is granted), producing `prd.md` in `.ensi/docs/`. |
| FR-07 | The system must execute the Architect stage after the PM stage completes (and human approval is granted), producing `architecture.md` in `.ensi/docs/`. |
| FR-08 | Each stage must validate its output against a defined schema before advancing. On validation failure, the system must retry up to 3 times before marking the session as failed. |
| FR-09 | The system must pause between stages and wait for explicit human approval before advancing. Approval is given by a designated comment on the Multica issue. |

### Artefact Management

| ID | Requirement |
|----|-------------|
| FR-10 | All artefacts (product-brief.md, prd.md, architecture.md) must be stored as plain markdown in `.ensi/docs/` within the project repo. |
| FR-11 | The system must commit artefacts to the project repository at each stage boundary so they are version-controlled and auditable. |
| FR-12 | Artefact filenames and directory structure must be consistent and predictable (no timestamps, no hashes in filenames). |

### Session State & Resumption

| ID | Requirement |
|----|-------------|
| FR-13 | The system must persist session state to a file (`.ensi/state.json`) in the project repo after every stage transition. |
| FR-14 | The system must resume a paused or interrupted session from the last successfully completed stage, without re-running completed stages. |
| FR-15 | The system must support concurrent sessions across different project repos; sessions must not interfere with each other. |

### Onboarding

| ID | Requirement |
|----|-------------|
| FR-16 | The system must be installable as a Multica agent with a single command (`multica agent add ensi`). No config file editing required beyond setting `ANTHROPIC_API_KEY`. |
| FR-17 | The system must display a clear, human-readable error message if `ANTHROPIC_API_KEY` is not set, with instructions for resolution. |

---

## 4. Non-Functional Requirements

### Performance

| ID | Requirement |
|----|-------------|
| NFR-01 | Analyst stage completion time must be < 5 minutes at p95 for a typical greenfield project brief. |
| NFR-02 | Full pipeline (Analyst + PM + Architect, excluding human review time) must complete in < 20 minutes at p95. |
| NFR-03 | Time from `multica agent add ensi` to first completed product-brief.md must be < 10 minutes on a clean setup. |

### Reliability

| ID | Requirement |
|----|-------------|
| NFR-04 | < 5% of sessions must require human restart due to agent error (non-human-caused failures). |
| NFR-05 | ≥ 80% of sessions must produce all three artefacts without manual intervention, given human approvals are provided. |
| NFR-06 | The system must handle Anthropic API transient errors with exponential backoff and a maximum of 3 retries before surfacing the error to the user. |

### Security

| ID | Requirement |
|----|-------------|
| NFR-07 | API keys must never be written to disk, logs, or artefacts. The system must read `ANTHROPIC_API_KEY` from environment variables exclusively. |
| NFR-08 | No PII must be stored in artefacts beyond what the user explicitly inputs into the planning session. |
| NFR-09 | No telemetry, usage data, or session content must be transmitted to any third party without explicit user opt-in. |

### Scalability

| ID | Requirement |
|----|-------------|
| NFR-10 | MVP scope is single-tenant: one Multica workspace, one user's API key. Multi-tenant and team API key management is post-MVP. |
| NFR-11 | The system must support concurrent sessions across multiple project repos without resource contention. |

### Observability

| ID | Requirement |
|----|-------------|
| NFR-12 | All stage transitions, retries, and errors must be logged to `.ensi/logs/` with ISO 8601 timestamps and log levels (INFO, WARN, ERROR). |
| NFR-13 | The Multica issue must always reflect the current pipeline state via status and comments, so users can determine session state without reading log files. |

### Compatibility

| ID | Requirement |
|----|-------------|
| NFR-14 | The system must run on Node.js v20+ on macOS and Linux. No OS-specific native dependencies permitted in MVP. |
| NFR-15 | The ACP SDK version must be pinned. The adapter layer must isolate ACP-specific code so a version upgrade or SDK swap does not require changes to the pipeline logic. |

---

## 5. Epics

### EP-01: Spike — ACP + Multica Integration
Validate that an ACP-compatible agent can register with the Multica daemon and exchange messages end-to-end without platform changes.
Stories: SP-01

### EP-02: Spike — BMad Prompt Portability
Validate that BMad Analyst, PM, and Architect prompts produce quality output via the Anthropic API without IDE context.
Stories: SP-02

### EP-03: Agent Infrastructure
Core ACP adapter, Multica daemon registration, task routing, and error handling.
Stories: US-01, US-08

### EP-04: Analyst Stage
End-to-end Analyst agent: issue trigger → clarifying dialogue → product-brief.md → commit → human approval gate.
Stories: US-02, US-03, US-05

### EP-05: PM Stage
End-to-end PM agent: consumes product-brief.md → produces prd.md with testable user stories → commit → human approval gate.
Stories: US-06, US-10

### EP-06: Architect Stage
End-to-end Architect agent: consumes prd.md → produces architecture.md (ADR) → commit → human approval gate.
Stories: US-09

### EP-07: Session State & Resume
Persistent session state, process-restart recovery, and session resumption flow.
Stories: US-07

### EP-08: Human-in-the-Loop Review Gate
Inter-stage pause, comment-based approval protocol, and timeout/cancellation handling.
Stories: US-04

---

## 6. User Stories

---

### SP-01: ACP + Multica Daemon Spike

**As** the engineering team,
**I want** to run a minimal ACP agent that registers with the Multica daemon and exchanges messages,
**so that** we confirm the core protocol integration assumption before committing to the full build.

**Acceptance Criteria:**

```gherkin
Given a local Multica daemon is running
When a minimal ACP agent is started with a valid ACP server config
Then the agent appears in `multica agent list` within 5 seconds
  And a test task sent via `multica` is received by the agent
  And the agent posts a response comment to the triggering issue
  And no changes to the Multica daemon source are required
```

**Effort:** S
**Dependencies:** ACP TypeScript SDK available, Multica daemon running locally
**Output:** Spike report documenting: registration method, message format, any gaps vs. ACP spec, pinned SDK version, adapter interface definition

---

### SP-02: BMad Prompt Portability Spike

**As** the engineering team,
**I want** to run BMad Analyst, PM, and Architect prompts standalone via the Anthropic API,
**so that** we confirm the prompts produce quality output without an IDE context before building three agents.

**Acceptance Criteria:**

```gherkin
Given the BMad Analyst prompt is extracted and wrapped in an Anthropic API call
When the prompt is executed for a simple greenfield project (e.g., "a to-do app")
Then a product-brief.md is produced that is rated ≥ 4/5 by a developer unfamiliar with the project
  And the brief is specific (not generic), coherent, and includes a clear problem statement and personas

Given the BMad PM prompt receives the Analyst output
When the prompt is executed via the Anthropic API
Then a PRD is produced with ≥ 3 testable user stories in Given/When/Then format

Given the BMad Architect prompt receives the PM output
When the prompt is executed via the Anthropic API
Then an architecture.md is produced with ≥ 1 concrete stack recommendation and documented trade-offs
```

**Effort:** S
**Dependencies:** SP-01 (ACP adapter not required; direct API call is sufficient for this spike)
**Output:** Spike report documenting: prompt extraction approach, quality rating results, wrapping strategy (system prompt vs. user prompt), any prompt modifications required

---

### US-01: Issue-Triggered Pipeline Start

**As** Marco (solo developer),
**I want** to tag a Multica issue `BP` and have Ensi automatically start the Analyst stage,
**so that** I get a structured planning session without manually invoking an agent.

**Acceptance Criteria:**

```gherkin
Given Ensi is registered in my Multica workspace
  And I have set ANTHROPIC_API_KEY in my environment
When I create a Multica issue with title containing "[BP]" or tag "BP"
Then Ensi receives the task within 10 seconds of issue creation
  And Ensi updates the issue status to "in_progress"
  And Ensi posts a comment confirming the Analyst stage has started
  And the Analyst stage begins without any further action from me
```

**Effort:** M
**Dependencies:** SP-01 (ACP integration spike must pass)
**Blockers:** Multica daemon trigger mechanism must be confirmed in SP-01

---

### US-02: Analyst Clarifying Dialogue

**As** Marco,
**I want** the Analyst to ask me targeted clarifying questions before writing the product brief,
**so that** the brief reflects my specific project context, not a generic template.

**Acceptance Criteria:**

```gherkin
Given the Analyst stage has started
When I respond to the first Analyst question via a comment on the Multica issue
Then the Analyst posts the next question or confirms it has enough context
  And the Analyst asks no more than 5 clarifying questions total
  And all questions are posted as comments on the triggering issue

Given the Analyst has asked all necessary questions
When I provide the final answer
Then the Analyst confirms it is generating the brief
  And no further input is required from me to produce product-brief.md
```

**Effort:** M
**Dependencies:** US-01, FR-09 (human approval gate infrastructure)

---

### US-03: Product Brief Artefact

**As** Marco,
**I want** the product-brief.md to be saved and committed in my project repo,
**so that** I can review and edit it before the PM stage begins.

**Acceptance Criteria:**

```gherkin
Given the Analyst has completed the clarifying dialogue
When the Analyst generates the product brief
Then product-brief.md is written to `.ensi/docs/product-brief.md` in the project repo
  And the file is committed with a descriptive commit message
  And Ensi posts a comment on the issue with a summary of the brief and a link to the file
  And the issue status is updated to "in_review"
```

**Effort:** S
**Dependencies:** US-02, FR-10, FR-11

---

### US-04: Human Review Gate Between Stages

**As** Ana (tech lead),
**I want** the pipeline to pause between stages until my team explicitly approves the artefact,
**so that** we can validate each output before the next agent runs.

**Acceptance Criteria:**

```gherkin
Given Ensi has completed the Analyst stage and posted product-brief.md
When my team reviews the brief in the project repo
  And a team member posts a comment containing "LGTM" or "approve" on the Multica issue
Then Ensi advances to the PM stage automatically
  And Ensi posts a confirmation comment that the PM stage has started

Given Ensi is waiting for approval
When 72 hours pass without an approval comment
Then Ensi posts a reminder comment mentioning the issue assignee
  And the issue status remains "in_review" (Ensi does not auto-advance)

Given Ensi is waiting for approval
When a team member posts "reject" or "restart" with a reason
Then Ensi re-runs the current stage with the rejection reason as additional context
```

**Effort:** M
**Dependencies:** FR-09, US-03

---

### US-05: Stage Completion Notifications

**As** Ana,
**I want** Ensi to post a comment when each stage completes,
**so that** my team can see planning progress on the Multica board without polling.

**Acceptance Criteria:**

```gherkin
Given any pipeline stage completes successfully
When the artefact is committed to the repo
Then Ensi posts a comment on the Multica issue including:
  - Which stage completed
  - A 2–3 sentence summary of the artefact
  - A relative path to the artefact file
  - Clear instructions for how to approve or reject

Given any pipeline stage fails after retries
When the failure is unrecoverable
Then Ensi posts a comment explaining the failure in plain language
  And the issue status is updated to "blocked"
```

**Effort:** S
**Dependencies:** FR-03, FR-04

---

### US-06: PRD with Testable Acceptance Criteria

**As** Ana,
**I want** the PRD to include testable acceptance criteria in Given/When/Then format for every user story,
**so that** the dev agents have unambiguous specs to implement against.

**Acceptance Criteria:**

```gherkin
Given the PM stage has received a product-brief.md
When the PM agent generates the PRD
Then prd.md contains ≥ 3 user stories
  And each user story has a unique ID (US-01, US-02, ...)
  And each user story has ≥ 1 acceptance criterion in Gherkin Given/When/Then format
  And each user story has an effort estimate (S/M/L/XL)
  And each user story references its parent epic
  And the PRD includes an explicit MVP scope section (in-scope and out-of-scope)
```

**Effort:** M
**Dependencies:** US-04 (PM stage triggered by approval of Analyst artefact)

---

### US-07: Session Resumption

**As** Marco,
**I want** to resume a paused or interrupted Ensi session from where it left off,
**so that** I don't lose planning progress if the agent restarts or I take a break.

**Acceptance Criteria:**

```gherkin
Given an Ensi session is in progress and the process is killed
When the Multica daemon restarts Ensi and the same issue is re-triggered
Then Ensi reads `.ensi/state.json` from the project repo
  And Ensi resumes from the last completed stage, not from the beginning
  And Ensi posts a comment confirming resumption and the current stage

Given `.ensi/state.json` is corrupted or missing
When Ensi tries to resume
Then Ensi posts a comment explaining that state could not be restored
  And Ensi offers to restart from the beginning with human confirmation
  And Ensi does not silently re-run completed stages
```

**Effort:** M
**Dependencies:** FR-13, FR-14

---

### US-08: Zero-Config Onboarding

**As** James (BMad user coming to Multica),
**I want** to add Ensi to my workspace and run my first session with a single command and no config file editing,
**so that** onboarding is fast enough that I don't give up.

**Acceptance Criteria:**

```gherkin
Given I have a Multica workspace and an Anthropic API key
When I run `multica agent add ensi` and set ANTHROPIC_API_KEY in my shell
Then Ensi is registered and visible in `multica agent list` within 60 seconds
  And no config file creation or editing is required
  And I can trigger a planning session by creating a BP-tagged issue immediately

Given I run `multica agent add ensi` without ANTHROPIC_API_KEY set
When the first BP-tagged issue is created
Then Ensi posts a comment with a clear error message explaining the missing key
  And the message includes the exact environment variable name and a one-sentence setup instruction
```

**Effort:** M
**Dependencies:** SP-01, FR-16, FR-17

---

### US-09: Architecture Decision Record

**As** Marco,
**I want** the Architect stage to produce an ADR with documented stack choices and trade-offs,
**so that** I have a written technical decision trail before any coding begins.

**Acceptance Criteria:**

```gherkin
Given the Architect stage has received prd.md
When the Architect agent generates the architecture document
Then architecture.md is written to `.ensi/docs/architecture.md`
  And the document includes ≥ 1 architectural decision in ADR format (Context / Decision / Consequences)
  And the document explicitly names the technology or pattern chosen for each major concern (runtime, storage, LLM interaction, artefact format)
  And rejected alternatives are listed with the reason for rejection
  And the document does not prescribe implementation details that belong to the coding phase
```

**Effort:** M
**Dependencies:** US-04 (Architect stage triggered by approval of PM artefact), US-06

---

### US-10: Pipeline Status on Multica Board

**As** Ana,
**I want** to see which pipeline stage Ensi is in from the Multica issue view,
**so that** I can track planning progress alongside development work without opening the repo.

**Acceptance Criteria:**

```gherkin
Given Ensi is executing any stage
When I view the triggering issue in Multica
Then the issue status reflects the current pipeline state:
  - "in_progress" while a stage is running
  - "in_review" while awaiting human approval
  - "blocked" if a stage has failed
  - "done" when all three artefacts are committed and approved

Given a stage completes
When I view the issue comments
Then the most recent Ensi comment clearly states which stage just completed
  And the comment includes the relative path to the new artefact
```

**Effort:** S
**Dependencies:** FR-03, FR-04, US-05

---

## 7. MVP Scope

### In Scope (v1)

- Spike SP-01: ACP + Multica daemon integration validation
- Spike SP-02: BMad prompt portability validation
- ACP agent registration with Multica daemon (no daemon fork)
- BP-tag trigger from Multica issues
- Analyst stage: clarifying dialogue → product-brief.md → commit
- PM stage: product-brief.md → prd.md → commit
- Architect stage: prd.md → architecture.md (ADR) → commit
- Human approval gate between each stage (comment-based)
- Stage completion and failure comments on Multica issues
- Issue status updates throughout pipeline
- Session state persistence (`.ensi/state.json`)
- Session resumption from last completed stage
- Zero-config onboarding via `multica agent add ensi`
- Greenfield projects only
- Anthropic API only (Claude Sonnet/Haiku)
- Node.js v20+, macOS and Linux

### Out of Scope (post-MVP)

| Feature | Reason deferred |
|---------|----------------|
| Brownfield / existing-codebase analysis | Requires repo scanning; higher complexity; separate spike needed |
| Multi-LLM provider support (OpenAI, Gemini) | Not required to validate core hypothesis; adds abstraction overhead |
| Developer / coding agent stage | Out of Ensi's planning-only mission; Multica already has coding agents |
| Rich artefact UI (web rendering, rich editor) | Plain markdown covers MVP needs; UI is a product layer decision |
| Billing / per-token metering | User provides own API key; metering is a platform concern |
| Multi-tenant / team API key management | Single-tenant assumption reduces auth complexity for MVP |
| Automated sprint planning from PRD | Requires deeper Multica board integration; post-validation feature |
| BMad Developer and QA agent stages | Spike must confirm Analyst/PM/Architect pipeline first |
| Slack / email notifications | Multica issue comments are sufficient for MVP |
| Custom approval keywords | "LGTM" / "approve" covers MVP; configurability is post-MVP |

### Minimum Viable Feature Set

To validate the core hypothesis — that structured AI planning improves downstream development quality on Multica — the MVP must demonstrate:
1. End-to-end pipeline from BP tag to committed architecture.md with human review at each gate.
2. Session resumption so users trust the system won't lose their work.
3. Zero-config onboarding so adoption friction is not the bottleneck.

Both spikes must pass before feature development begins. A failed spike requires a scope pivot.

---

## 8. Open Questions

| # | Question | Owner | Needed by |
|---|----------|-------|-----------|
| OQ-01 | What exact Multica daemon registration API does an ACP agent use? Is there a published endpoint spec or only convention? | Architect (post SP-01) | Before EP-03 |
| OQ-02 | Does `multica agent add` support a registry / npm-install flow, or does the binary need to be on PATH manually? | Engineering (spike SP-01) | Before US-08 |
| OQ-03 | What is the approval comment syntax? Should Ensi support natural language approval detection or a strict keyword? | Product / Ana persona | Before US-04 implementation |
| OQ-04 | Should the human approval gate be skippable via a config option (e.g., `ENSI_AUTO_ADVANCE=true`) for automated pipelines? | Product | Before US-04 implementation |
| OQ-05 | Is `.ensi/state.json` safe to commit to a public repo, or should state be gitignored by default? | Architect | Before US-07 implementation |
| OQ-06 | What is the Multica daemon's behaviour when an ACP agent is unreachable — does it retry, surface an error to the issue, or silently drop the task? | Architect (post SP-01) | Before EP-03 |
| OQ-07 | Are there rate limits on `multica issue comment add` that could affect stage progress updates during long-running LLM calls? | Engineering | Before EP-04 |
| OQ-08 | Should the 72-hour approval timeout be configurable per workspace, per project, or global? | Product | Before US-04 implementation |
| OQ-09 | BMad prompts reference specific Multica conventions (issue IDs, comment syntax). How much prompt adaptation is required for general greenfield projects? | Engineering (spike SP-02) | Before EP-04 |
| OQ-10 | Does the Architect stage need access to the project's existing repo (git history, package.json) for greenfield, or is the PRD sufficient input? | Architect | Before EP-06 |
