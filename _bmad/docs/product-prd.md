# Product Requirements Document: Ensi — BMAD Method for Multica

**Date:** 2026-04-17
**Author:** PM Agent (BMAD pipeline — Curly)
**Status:** Complete — awaiting Architect review
**Input:** `_bmad/docs/brief-artifact.json` + `_bmad/docs/product-brief.md` (Analyst, 2026-04-17)

---

## 1. Product Overview

### Vision
Ensi is an ACP-compatible agent that brings the proven BMAD planning methodology (Analyst → PM → Architect) into the Multica workspace as autonomous teammates, eliminating the gap between ideation and implementation for teams using managed AI agents.

### Problem Summary
Teams on Multica skip structured planning and jump straight to coding agents, causing rework, scope creep, and missed requirements. BMad Method (45k+ stars) provides the methodology but is CLI-only and stateless. Multica has the platform but no planning layer. Ensi bridges them via ACP.

### Target Users
- **Marco** (P-01) — Solo AI-Forward Developer. Wants a structured brief before assigning coding issues, without leaving Multica.
- **Ana** (P-02) — Small Engineering Team Lead. Needs consistent planning artefacts that the team can review before any code is written.
- **James** (P-03) — AI Enablement Engineer, BMad power user. Wants session persistence and team visibility without the CLI.

---

## 2. Validation Spikes — Pre-Build Gates

> **Both spikes must pass before user story implementation begins.** They de-risk the two highest-impact assumptions in the product brief. A failed spike triggers a scope renegotiation, not a workaround.

### SP-01 — ACP + Multica Daemon Integration

**Goal:** Prove that an ACP-compatible TypeScript agent can register with the Multica daemon, receive a task, and post a response — end-to-end — without forking Multica.

**Done when:**
- A minimal "hello world" ACP agent (< 50 LOC) registers with the local Multica daemon
- The agent receives a task payload sent via `multica` CLI
- The agent posts a comment back to the triggering issue
- No daemon fork, monkey-patching, or undocumented APIs required
- ACP SDK version is pinned; adapter layer interface is defined

**Fail criteria:** If registration or message exchange requires changes to the Multica daemon source, stop and escalate. The full build is not viable without a first-class ACP integration path.

**Effort:** S (1–2 days) | **Blocks:** EP-03

---

### SP-02 — BMad Prompt Portability

**Goal:** Confirm that core BMad Analyst, PM, and Architect prompts produce useful structured output when invoked via the Anthropic API directly — without an IDE, CLAUDE.md context, or human guidance during generation.

**Done when:**
- Analyst prompt produces a product-brief.md rated ≥ 4/5 by a developer unfamiliar with the project
- PM prompt consumes the brief and produces a PRD with ≥ 3 testable user stories in Gherkin format
- Architect prompt consumes the PRD and produces an ADR with ≥ 1 concrete stack recommendation
- All prompts run without modification to core BMad prompt text (adapt wrapping, not content)

**Fail criteria:** If output quality < 3/5 or prompts require substantial rewriting, escalate to a dedicated prompt-porting workstream before committing to the full build.

**Effort:** S (1–2 days) | **Blocks:** EP-04, EP-05, EP-06

---

## 3. Functional Requirements

### Agent Protocol & Platform Integration

| ID | Requirement |
|----|-------------|
| FR-01 | The system must expose an ACP-compatible agent interface that the Multica daemon can discover and register automatically. |
| FR-02 | The system must receive task payloads from the Multica daemon when a Multica issue is tagged `BP` (Brainstorm/Planning). |
| FR-03 | The system must post structured comments to the triggering Multica issue at stage completion, stage failure, and when awaiting human input. |
| FR-04 | The system must update the Multica issue status to reflect pipeline state (`in_progress`, `in_review`, `blocked`, `done`). |

### Planning Pipeline

| ID | Requirement |
|----|-------------|
| FR-05 | The system must execute the Analyst stage first, producing `product-brief.md` in `.ensi/docs/`. |
| FR-06 | The system must execute the PM stage after the Analyst completes and human approval is granted, producing `prd.md` in `.ensi/docs/`. |
| FR-07 | The system must execute the Architect stage after the PM completes and human approval is granted, producing `architecture.md` in `.ensi/docs/`. |
| FR-08 | Each stage must validate its output against a defined schema before advancing. On validation failure, retry up to 3 times before marking the session failed. |
| FR-09 | The system must pause between stages and wait for explicit human approval (comment containing `LGTM` or `approve`) before advancing. |

### Artefact Management

| ID | Requirement |
|----|-------------|
| FR-10 | All artefacts must be stored as plain markdown in `.ensi/docs/` within the project repo. |
| FR-11 | The system must commit artefacts to the project repository at each stage boundary so they are version-controlled and auditable. |
| FR-12 | Artefact filenames must be consistent and predictable — no timestamps or hashes. |

### Session State & Resumption

| ID | Requirement |
|----|-------------|
| FR-13 | The system must persist session state to `.ensi/state.json` after every stage transition. |
| FR-14 | The system must resume a paused or interrupted session from the last successfully completed stage, without re-running completed stages. |
| FR-15 | The system must support concurrent sessions across different project repos without interference. |

### Onboarding

| ID | Requirement |
|----|-------------|
| FR-16 | The system must be installable as a Multica agent with a single command (`multica agent add ensi`). No config file editing required beyond setting `ANTHROPIC_API_KEY`. |
| FR-17 | The system must display a clear, human-readable error message if `ANTHROPIC_API_KEY` is not set, with setup instructions. |

---

## 4. Non-Functional Requirements

### Performance

| ID | Target |
|----|--------|
| NFR-01 | Analyst stage completion < 5 minutes at p95 for a typical greenfield project brief. |
| NFR-02 | Full pipeline (Analyst + PM + Architect, excluding human review time) < 20 minutes at p95. |
| NFR-03 | Time from `multica agent add ensi` to first completed `product-brief.md` < 10 minutes on a clean setup. |

### Reliability

| ID | Target |
|----|--------|
| NFR-04 | < 5% of sessions require human restart due to agent error. |
| NFR-05 | ≥ 80% of sessions produce all three artefacts without manual intervention (given approvals are provided). |
| NFR-06 | Anthropic API transient errors handled with exponential backoff, max 3 retries before surfacing to user. |

### Security

| ID | Requirement |
|----|-------------|
| NFR-07 | API keys must never be written to disk, logs, or artefacts. Read `ANTHROPIC_API_KEY` from environment variables exclusively. |
| NFR-08 | No PII stored in artefacts beyond what the user explicitly inputs. |
| NFR-09 | No telemetry or session content transmitted to any third party without explicit opt-in. |

### Scalability

| ID | Requirement |
|----|-------------|
| NFR-10 | MVP: single-tenant (one workspace, one user's API key). Multi-tenant is post-MVP. |
| NFR-11 | Concurrent sessions across multiple project repos must not contend on shared resources. |

### Observability

| ID | Requirement |
|----|-------------|
| NFR-12 | All stage transitions, retries, and errors logged to `.ensi/logs/` with ISO 8601 timestamps and levels (INFO, WARN, ERROR). |
| NFR-13 | Multica issue must always reflect current pipeline state via status and comments — no need to read log files. |

### Compatibility

| ID | Requirement |
|----|-------------|
| NFR-14 | Must run on Node.js v20+ on macOS and Linux. No OS-specific native dependencies in MVP. |
| NFR-15 | ACP SDK version must be pinned. Adapter layer must isolate ACP-specific code so a version upgrade does not require changes to pipeline logic. |

---

## 5. Artifact Schemas

> **Decision:** Finalize these schemas before writing persona prompts. They are the contracts that all agents use — changing a schema mid-build requires updating all agents that read or write it.

The five MVP artifact schemas are fully defined in `_bmad/docs/prd-artifact.json` under `artifact_schemas`. Summary:

| Schema | Stage | Produced By | Key Fields |
|--------|-------|-------------|------------|
| `BriefArtifact` | Discovery | Analyst | vision, problem_statement, personas, features_classified, risks, assumptions, success_metrics |
| `PrdArtifact` | Planning | PM | pipeline_stages, features (with Gherkin AC), functional/NFRs, artifact_schemas, out_of_scope, open_questions |
| `ArchitectureArtifact` | Architecture | Architect | tech_stack, components, ADRs (Context/Decision/Consequences), deployment |
| `SprintPlanArtifact` | Development | Scrum Master (v2) | sprint_goal, stories (estimate + status), definition_of_done |
| `CodeReviewArtifact` | Review | Code Reviewer | issues (severity, file, line, recommendation), summary (counts by severity), approval decision |

**Schema design principles:**
- Every field has a defined type; arrays have `minItems` where a minimum is meaningful
- IDs follow predictable patterns: `P-01`, `FR-01`, `ADR-01`, `CR-01`, etc.
- Each artifact references `input_artifact` to form a traceable chain (Brief → PRD → Architecture → Sprint → Review)
- `produced_by` and `status` fields are enums, not free strings — schema validation can reject invalid values

---

## 6. Epics

| ID | Title | Description | Stories |
|----|-------|-------------|---------|
| EP-01 | Spike: ACP + Multica Integration | Validate ACP agent can register and exchange messages with Multica daemon | SP-01 |
| EP-02 | Spike: BMad Prompt Portability | Validate BMad prompts produce quality output via Anthropic API without IDE | SP-02 |
| EP-03 | Agent Infrastructure | ACP adapter, daemon registration, task routing, error handling, onboarding | US-01, US-08, F-005 |
| EP-04 | Analyst Stage | Clarifying dialogue → product-brief.md → commit → approval gate | US-02, US-03, US-05 |
| EP-05 | PM Stage | product-brief.md → prd.md with testable ACs → commit → approval gate | US-06, US-10 |
| EP-06 | Architect Stage | prd.md → architecture.md (ADR) → commit → approval gate | US-09 |
| EP-07 | Session State & Resume | Persistent state, process-restart recovery, session resumption | US-07 |
| EP-08 | Human-in-the-Loop Gate | Inter-stage pause, approval protocol, timeout/cancellation handling | US-04 |

---

## 7. User Stories

---

### SP-01 — ACP + Multica Daemon Spike

**As** the engineering team,
**I want** to run a minimal ACP agent that registers with the Multica daemon and exchanges messages,
**so that** we confirm the core protocol integration assumption before committing to the full build.

```gherkin
Given a local Multica daemon is running
When a minimal ACP agent is started with a valid ACP server config
Then the agent appears in `multica agent list` within 5 seconds
  And a test task sent via `multica` is received by the agent
  And the agent posts a response comment to the triggering issue
  And no changes to the Multica daemon source are required
```

**Effort:** S | **Output:** Spike report: registration method, message format, gaps vs. ACP spec, pinned SDK version, adapter interface definition

---

### SP-02 — BMad Prompt Portability Spike

**As** the engineering team,
**I want** to run BMad Analyst, PM, and Architect prompts standalone via the Anthropic API,
**so that** we confirm the prompts produce quality output without IDE context before building three agents.

```gherkin
Given the BMad Analyst prompt is extracted and wrapped in an Anthropic API call
When the prompt is executed for a simple greenfield project
Then a product-brief.md is produced rated >= 4/5 by an unfamiliar developer
  And the brief is specific, coherent, and includes a clear problem statement and personas

Given the BMad PM prompt receives the Analyst output
When the prompt is executed via the Anthropic API
Then a PRD is produced with >= 3 testable user stories in Given/When/Then format

Given the BMad Architect prompt receives the PM output
When the prompt is executed via the Anthropic API
Then an architecture.md is produced with >= 1 concrete stack recommendation and documented trade-offs
```

**Effort:** S | **Output:** Spike report: prompt extraction approach, quality ratings, wrapping strategy, any modifications required

---

### US-01 — Issue-Triggered Pipeline Start

**As** Marco, **I want** to tag a Multica issue `BP` and have Ensi automatically start the Analyst stage, **so that** I get a structured planning session without manually invoking an agent.

```gherkin
Given Ensi is registered in my Multica workspace
  And ANTHROPIC_API_KEY is set in the environment
When I create a Multica issue with the "BP" tag
Then Ensi receives the task within 10 seconds of issue creation
  And Ensi updates the issue status to "in_progress"
  And Ensi posts a comment confirming the Analyst stage has started
  And the Analyst stage begins without further action from me
```

**Effort:** M | **Dependencies:** SP-01 | **Blockers:** Multica daemon trigger mechanism must be confirmed in SP-01

---

### US-02 — Analyst Clarifying Dialogue

**As** Marco, **I want** the Analyst to ask me targeted clarifying questions before writing the product brief, **so that** the brief reflects my specific project context.

```gherkin
Given the Analyst stage has started
When I respond to the first Analyst question via a comment on the Multica issue
Then the Analyst posts the next question or confirms sufficient context
  And the Analyst asks no more than 5 clarifying questions total
  And all questions are posted as comments on the triggering issue

Given the Analyst has asked all necessary questions
When I provide the final answer
Then the Analyst confirms it is generating the brief
  And no further input is required to produce product-brief.md
```

**Effort:** M | **Dependencies:** US-01, FR-09

---

### US-03 — Product Brief Artefact

**As** Marco, **I want** `product-brief.md` to be saved and committed in my project repo, **so that** I can review and edit it before the PM stage begins.

```gherkin
Given the Analyst has completed the clarifying dialogue
When the Analyst generates the product brief
Then product-brief.md is written to `.ensi/docs/product-brief.md` in the project repo
  And the file is committed with a descriptive commit message
  And Ensi posts a comment on the issue with a brief summary and file path
  And the issue status is updated to "in_review"
```

**Effort:** S | **Dependencies:** US-02, FR-10, FR-11

---

### US-04 — Human Review Gate Between Stages

**As** Ana, **I want** the pipeline to pause between stages until my team explicitly approves the artefact, **so that** we can validate each output before the next agent runs.

```gherkin
Given Ensi has completed a stage and the artefact is committed
When a team member posts a comment containing "LGTM" or "approve"
Then Ensi advances to the next stage automatically
  And Ensi posts a confirmation comment that the next stage has started

Given Ensi is waiting for approval
When 72 hours pass without an approval comment
Then Ensi posts a reminder comment mentioning the issue assignee
  And the issue status remains "in_review" (Ensi does not auto-advance)

Given Ensi is waiting for approval
When a team member posts "reject" or "restart" with a reason
Then Ensi re-runs the current stage with the rejection reason as additional context
```

**Effort:** M | **Dependencies:** FR-09, US-03

---

### US-05 — Stage Completion Notifications

**As** Ana, **I want** Ensi to post a comment when each stage completes, **so that** my team can see planning progress on the Multica board without polling.

```gherkin
Given any pipeline stage completes successfully
When the artefact is committed to the repo
Then Ensi posts a comment including:
  - Which stage completed
  - A 2-3 sentence summary of the artefact
  - The relative path to the artefact file
  - Clear instructions for how to approve or reject

Given any pipeline stage fails after retries
When the failure is unrecoverable
Then Ensi posts a comment explaining the failure in plain language
  And the issue status is updated to "blocked"
```

**Effort:** S | **Dependencies:** FR-03, FR-04

---

### US-06 — PRD with Testable Acceptance Criteria

**As** Ana, **I want** the PRD to include testable acceptance criteria in Given/When/Then format for every user story, **so that** dev agents have unambiguous specs to implement against.

```gherkin
Given the PM stage has received a product-brief.md
When the PM agent generates the PRD
Then prd.md contains >= 3 user stories
  And each user story has a unique ID (US-01, US-02, ...)
  And each user story has >= 1 acceptance criterion in Gherkin Given/When/Then format
  And each user story has an effort estimate (S/M/L/XL)
  And each user story references its parent epic
  And the PRD includes an explicit MVP scope section (in-scope and out-of-scope)
```

**Effort:** M | **Dependencies:** US-04

---

### US-07 — Session Resumption

**As** Marco, **I want** to resume a paused or interrupted Ensi session from where it left off, **so that** I don't lose planning progress if the agent restarts.

```gherkin
Given an Ensi session is in progress and the process is killed
When the Multica daemon restarts Ensi and the same issue is re-triggered
Then Ensi reads `.ensi/state.json` from the project repo
  And Ensi resumes from the last completed stage, not from the beginning
  And Ensi posts a comment confirming resumption and the current stage

Given `.ensi/state.json` is corrupted or missing
When Ensi tries to resume
Then Ensi posts a comment explaining state could not be restored
  And Ensi offers to restart from the beginning with human confirmation
  And Ensi does not silently re-run completed stages
```

**Effort:** M | **Dependencies:** FR-13, FR-14

---

### US-08 — Zero-Config Onboarding

**As** James, **I want** to add Ensi to my workspace and run my first session with a single command and no config file editing, **so that** onboarding is fast enough that I don't give up.

```gherkin
Given I have a Multica workspace and an Anthropic API key
When I run `multica agent add ensi` and set ANTHROPIC_API_KEY in my shell
Then Ensi is registered and visible in `multica agent list` within 60 seconds
  And no config file creation or editing is required
  And I can trigger a planning session by creating a BP-tagged issue immediately

Given I run `multica agent add ensi` without ANTHROPIC_API_KEY set
When the first BP-tagged issue is created
Then Ensi posts a comment with a clear error message
  And the message includes the exact environment variable name and a one-sentence setup instruction
```

**Effort:** M | **Dependencies:** SP-01, FR-16, FR-17

---

### US-09 — Architecture Decision Record

**As** Marco, **I want** the Architect stage to produce an ADR with documented stack choices and trade-offs, **so that** I have a written technical decision trail before any coding begins.

```gherkin
Given the Architect stage has received prd.md
When the Architect agent generates the architecture document
Then architecture.md is written to `.ensi/docs/architecture.md`
  And the document includes >= 1 architectural decision in ADR format (Context / Decision / Consequences)
  And the document explicitly names the technology chosen for each major concern
  And rejected alternatives are listed with reasons for rejection
  And the document does not prescribe implementation details belonging to the coding phase
```

**Effort:** M | **Dependencies:** US-04, US-06

---

### US-10 — Pipeline Status on Multica Board

**As** Ana, **I want** to see which pipeline stage Ensi is in from the Multica issue view, **so that** I can track planning progress alongside development work.

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

**Effort:** S | **Dependencies:** FR-03, FR-04, US-05

---

## 8. MVP Scope

### In Scope (v1)

- Spike SP-01: ACP + Multica daemon integration validation
- Spike SP-02: BMad prompt portability validation
- ACP agent registration with Multica daemon (no daemon fork)
- BP-tag trigger from Multica issues
- Analyst stage: clarifying dialogue → `product-brief.md` → commit
- PM stage: `product-brief.md` → `prd.md` → commit
- Architect stage: `prd.md` → `architecture.md` (ADR) → commit
- Human approval gate between each stage (comment-based)
- Stage completion and failure comments on Multica issues
- Issue status updates throughout pipeline
- Session state persistence (`.ensi/state.json`)
- Session resumption from last completed stage
- Zero-config onboarding via `multica agent add ensi`
- Greenfield projects only
- Anthropic API only (Claude Sonnet/Haiku)
- Node.js v20+, macOS and Linux

### Out of Scope (v2+)

| Feature | Reason Deferred |
|---------|-----------------|
| Deploy stage | Not needed to validate core planning hypothesis |
| Observability stage (OTel traces) | Deferred — `.ensi/logs/` covers MVP observability |
| Agent Memory (vector search) | Over-engineered for MVP file-based state |
| Transversal agents beyond Code Reviewer | Validate Analyst/PM/Architect first |
| Multi-LLM support | Not required to validate hypothesis; adds abstraction overhead |
| Brownfield / existing-codebase analysis | Requires repo scanning; separate spike needed |
| Rich artefact UI | Plain markdown covers MVP needs |
| Billing / per-token metering | User provides own API key |
| Multi-tenant / team API key management | Single-tenant assumption reduces auth complexity |
| Automated sprint planning from PRD | Requires deeper Multica board integration |
| Custom approval keywords | LGTM / approve covers MVP |
| Slack / email notifications | Multica issue comments sufficient |

### Minimum Viable Feature Set

To validate the core hypothesis — that structured AI planning improves downstream development quality on Multica — the MVP must demonstrate:

1. **End-to-end pipeline**: BP tag → committed `architecture.md`, with human review at each gate.
2. **Session resumption**: Users trust the system won't lose their work on restart.
3. **Zero-config onboarding**: Adoption friction is not the bottleneck.

Both spikes must pass before feature development begins. A failed spike requires a scope pivot.

### 8-Week Schedule Validation

| Week | Deliverable | Stories |
|------|-------------|---------|
| 1 | SP-01 + SP-02 complete; adapter interface defined | SP-01, SP-02 |
| 2 | ACP registration + BP-tag trigger working end-to-end | US-01, US-08 |
| 3 | Analyst clarifying dialogue + product-brief.md committed | US-02, US-03 |
| 4 | Human review gate + stage notifications | US-04, US-05 |
| 5 | PM stage complete: prd.md with Gherkin ACs | US-06, US-10 |
| 6 | Session state persistence + resumption | US-07 |
| 7 | Architect stage complete: architecture.md with ADR | US-09 |
| 8 | Integration testing, bug fixes, onboarding polish | — |

**Assessment:** 8 weeks is achievable for a focused 1–2 person team, provided both spikes pass in Week 1. The schedule has no slack for a failed spike — if either spike reveals a blocking issue, Week 2 becomes a pivot/scope-reduction week. The human approval gate (US-04) is the highest-risk story for unexpected complexity.

---

## 9. Open Questions

| # | Question | Owner | Needed By |
|---|----------|-------|-----------|
| OQ-01 | What exact Multica daemon registration API does an ACP agent use? Published spec or convention only? | Architect (post SP-01) | Before EP-03 |
| OQ-02 | Does `multica agent add` support a registry/npm-install flow, or must the binary be on PATH manually? | Engineering (SP-01) | Before US-08 |
| OQ-03 | Approval comment syntax: natural language detection or strict keyword (`LGTM`, `approve`)? | Product | Before US-04 |
| OQ-04 | Should the approval gate be skippable via `ENSI_AUTO_ADVANCE=true` for automated pipelines? | Product | Before US-04 |
| OQ-05 | Is `.ensi/state.json` safe to commit to a public repo, or gitignored by default? | Architect | Before US-07 |
| OQ-06 | Multica daemon behaviour when ACP agent is unreachable — retry, surface error, or drop silently? | Architect (post SP-01) | Before EP-03 |
| OQ-07 | Rate limits on `multica issue comment add` that could affect progress updates during long LLM calls? | Engineering | Before EP-04 |
| OQ-08 | Should the 72-hour approval timeout be configurable per workspace, project, or global? | Product | Before US-04 |
| OQ-09 | How much prompt adaptation is required to port BMad prompts for general greenfield via Anthropic API? | Engineering (SP-02) | Before EP-04 |
| OQ-10 | Does the Architect stage need access to the project's existing repo, or is the PRD sufficient input? | Architect | Before EP-06 |
