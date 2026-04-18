# Product Brief: Ensi — BMAD Method for Multica

**Date:** 2026-04-17
**Author:** Analyst Agent (BMAD pipeline)
**Status:** Draft — awaiting PM review

---

## 1. Project Vision & Problem Statement

### Vision
Ensi is an ACP-compatible agent that brings structured software planning directly into the Multica workspace. It orchestrates the BMAD Method pipeline — Analyst → PM → Architect — as autonomous teammates, producing persistent markdown artefacts that feed the development phase. The name comes from Finnish *ensi* ("first") — the first step before coding.

### Problem Statement
Developers face a structural gap between ideation and implementation:

- **BMad Method** (45k+ GitHub stars) provides a battle-tested planning framework but is CLI-only, IDE-dependent, and has no stateful session management or visual interface.
- **Multica** provides a managed multi-agent platform with task tracking and team delegation but ships no planning or discovery agents — its agents start at the coding phase.
- **The result:** teams on Multica skip structured planning entirely, creating rework, scope creep, and missed requirements downstream.

No product currently bridges structured AI planning workflows (BMad-style Analyst → PM → Architect) with a managed agent platform (Multica) via an open agent protocol (ACP). Ensi fills that gap.

---

## 2. Target Audience & User Personas

### Persona 1 — Solo Developer, Multica user ("Marco")
- **Profile:** Full-stack dev, uses Multica to delegate coding tasks to agents. Comfortable with AI tooling.
- **Pain point:** Starts coding before the problem is fully understood. Wastes cycles on features nobody needs.
- **Goal:** Get a structured brief and feature list before assigning coding issues — without leaving Multica.
- **Trigger:** Creates an issue tagged BP (Brainstorm/Planning); Ensi runs automatically.

### Persona 2 — Tech Lead, team of 3-5 devs ("Ana")
- **Profile:** Leads a small product team. Uses Multica as the team's project board.
- **Pain point:** Planning sessions are ad-hoc. No consistent artefacts (briefs, PRDs, ADRs). Technical decisions aren't documented.
- **Goal:** Ensi acts as a planning teammate — produces briefs and ADRs that the team can review before any code is written.
- **Trigger:** Tags issues for planning; uses artefacts as input to sprint planning.

### Persona 3 — BMad Method user, not yet on Multica ("James")
- **Profile:** Uses BMad via Claude Code or Cursor. Values structured planning but dislikes CLI-only workflows.
- **Pain point:** Each BMad session is ephemeral — no state persistence, no team visibility, no audit trail.
- **Goal:** Resume sessions, share artefacts with teammates, see progress on a board.
- **Trigger:** Discovery of Ensi brings him to Multica. Familiar with the BMad persona names.

---

## 3. Key Goals

1. **Deliver BMAD Analyst → PM → Architect pipeline** inside Multica as a single ACP agent.
2. **Persist all artefacts** (product-brief.md, prd.md, architecture.md) in `.ensi/docs/` within the project repo.
3. **Stateful session management** — sessions can be paused and resumed; state survives process restarts.
4. **Handoff protocol** — each stage produces a structured output and triggers the next stage automatically.
5. **Zero-config onboarding** — developers add Ensi as a Multica agent with no BMad CLI installation required.

### Non-Goals (MVP)
- **Developer/coding agent** — Ensi does planning only; coding is delegated to existing Multica dev agents.
- **Custom LLM provider support** — MVP uses Anthropic API only; multi-provider is post-MVP.
- **Existing-codebase analysis** — MVP scope is greenfield projects; brownfield support is post-MVP.
- **UI customisation** — Artefacts are plain markdown; no web rendering or rich editor in MVP.
- **Billing / metering** — No per-token accounting in MVP; relies on user's own Anthropic API key.

---

## 4. Competitive Landscape

| Product | Planning Approach | Key Gap vs. Ensi |
|---|---|---|
| **GitHub Copilot Workspace** | Plan → approve → execute; strong GitHub Issues integration | Proprietary, GitHub-only, no persistent BMAD-style artefacts, technical preview ended May 2025 |
| **Devin 2.0** | Fully autonomous; minimal human checkpoints | No structured planning methodology; expensive; not designed for planning-first workflows |
| **Cursor Agents** | Plan persisted to `.cursor/plans/`; multi-agent via worktrees | Local-only, IDE-bound; no team visibility; not composable as a Multica agent |
| **BMad Method (raw)** | Full Analyst→PM→Architect pipeline; 45k stars | CLI-only, IDE-dependent, stateless (no session resume), no platform integration |
| **MCP + mcp-agent** | Composable planning + worker agents; Temporal for recovery | Open standard but no BMad workflow, no Multica integration, high integration effort |

**Ensi's differentiator:** the only product combining (a) the proven BMad planning methodology, (b) Multica's managed-agent platform with board visibility, and (c) ACP protocol for open interoperability.

---

## 5. Constraints

### Technical
- Must be ACP-compatible (Agent Client Protocol, Apache 2.0, TypeScript SDK)
- Must integrate with Multica daemon/CLI architecture (daemon auto-detects agents on PATH)
- Artefacts stored in `.ensi/docs/` (markdown) within the checked-out project repo
- LLM: Anthropic API (Claude Sonnet/Haiku); MVP does not need to support other providers
- Runtime: Node.js v20+ (TypeScript/Node.js, consistent with ACP SDK)
- Session state: must survive process restarts; lightweight persistence needed (file-based or embedded DB)

### Business
- Apache-2.0 license (compatible with ACP SDK; BMad is MIT — compatible)
- MVP scope: 3 agents (Analyst, PM, Architect), 1 workflow (greenfield)
- No external service dependencies beyond Anthropic API and Multica daemon

### Compliance
- No PII stored in artefacts beyond what the user explicitly inputs
- API keys must never be persisted to disk in plaintext; use environment variables
- No telemetry without explicit opt-in

### Timeline
- No hard deadline specified; MVP should be deliverable in a single sprint (1-2 weeks of focused work)

---

## 6. Risks (Impact × Probability)

| # | Risk | Impact | Probability | Score | Mitigation |
|---|---|---|---|---|---|
| 1 | ACP SDK is immature (147 stars, limited adoption) — breaking changes or missing features | High | High | 9 | Pin SDK version; abstract behind thin adapter layer so swap is isolated |
| 2 | Multica daemon API changes break agent registration | High | Medium | 6 | Use only stable CLI commands; monitor Multica changelog; integration tests |
| 3 | LLM output non-determinism breaks structured handoffs (Analyst output doesn't parse cleanly for PM) | High | Medium | 6 | Define strict output schemas per stage; validate before advancing; retry on parse failure |
| 4 | BMad workflow doesn't translate well to async, multi-turn Multica task model | High | Medium | 6 | Prototype Analyst stage first as a spike; validate fit before building PM/Architect stages |
| 5 | Anthropic API latency/cost makes planning sessions feel slow or expensive | Medium | Medium | 4 | Use Haiku for fast/cheap iterative steps; Sonnet for final artefact generation; expose cost estimates |
| 6 | Adoption friction — devs don't know what "BP" tag triggers | Low | High | 3 | Clear onboarding docs; autopilot trigger config visible in Multica UI |

---

## 7. Assumptions Requiring Validation

1. **Multica daemon supports ACP agents today** — ACP TypeScript SDK agents can register with the Multica daemon without custom fork. *Validate:* run a minimal ACP agent against the daemon before scoping the full build.
2. **BMad Analyst→PM→Architect prompts are portable** — the core BMad prompts can be extracted from the IDE-oriented CLAUDE.md files and work standalone via Anthropic API without an IDE context. *Validate:* test BMad prompts directly via the API.
3. **File-based state is sufficient for MVP** — `.ensi/state.json` in the project repo is enough to resume sessions; no embedded database needed. *Validate:* model the state schema upfront.
4. **Multica issue trigger (BP tag) is the right UX** — users are comfortable with a tag-based trigger. *Validate:* user interviews or Discord feedback before investing in alternative trigger models.
5. **Three agents (Analyst, PM, Architect) cover 80% of greenfield planning needs** — the Developer agent and specialist agents are genuinely post-MVP. *Validate:* survey a sample of BMad Method users.

---

## 8. Success Metrics (KPIs)

### Adoption
- 50 unique workspaces running Ensi within 30 days of public release
- 200 planning sessions completed in the first 60 days

### Quality
- ≥ 80% of sessions produce all three artefacts (brief, PRD, ADR) without manual intervention
- < 5% of sessions require a human to restart due to agent error

### Engagement
- ≥ 60% of completed briefs are progressed to the PM stage (not abandoned after Analyst)
- Average session duration: Analyst stage < 5 minutes, full pipeline < 20 minutes

### Developer Experience
- Time to first brief (from `multica agent add ensi` to completed product-brief.md): < 10 minutes
- Zero-config: no file editing required beyond setting `ANTHROPIC_API_KEY`

---

## 9. Technology Considerations

The Architect should evaluate the following trade-offs. No stack is prescribed here.

### Agent runtime
| Option | Trade-offs |
|---|---|
| **Pure ACP SDK (TypeScript)** | Aligns with protocol; low-level; requires more orchestration code |
| **ACP SDK + LangGraph** | State machine support built-in; adds dependency; may be overkill for 3-stage pipeline |
| **ACP SDK + custom state machine** | Minimal deps; more control; more code to write and test |

### Session state persistence
| Option | Trade-offs |
|---|---|
| **JSON file in `.ensi/`** | Zero deps; human-readable; not safe for concurrent access |
| **SQLite (better-sqlite3)** | Lightweight; concurrent-safe; adds native dep (compilation) |
| **Redis (optional)** | Needed only if multi-instance; overkill for MVP |

### LLM interaction
| Option | Trade-offs |
|---|---|
| **Anthropic SDK direct** | Minimal; full control; no abstraction overhead |
| **Vercel AI SDK** | Provider-agnostic; adds complexity; useful if multi-provider is near-term |

### Artefact format
| Option | Trade-offs |
|---|---|
| **Plain markdown** | Universal; human-editable; no tooling required |
| **Structured YAML frontmatter + markdown** | Machine-parseable metadata; slight authoring overhead |

**Recommendation to Architect:** favour minimal dependencies for MVP. Complexity budget should go into prompt quality and state machine correctness, not framework wiring.

---

## 10. Brainstorming Outputs

### Technique 1: Ideal Future State (12 months)
Ensi is the default planning layer for Multica workspaces. A developer creates an issue, tags it `[BP]`, and 15 minutes later has a product brief, a PRD with prioritised features, and an ADR with the selected architecture — all reviewed and approved via the Multica board. The coding agents pick up issues directly from the PRD. The team ships features that were planned, not just features that were easy.

### Technique 2: What Could Go Wrong?
- The ACP SDK ecosystem doesn't grow — Ensi becomes the only ACP agent anyone builds, and the protocol atrophies.
- BMad prompts are too opinionated — they produce briefs that feel generic, not tailored to the specific project context.
- Multica adds native planning features — Ensi's value proposition is commoditised.
- The three-agent pipeline is too slow — developers skip planning and go straight to coding agents anyway.
- Maintenance burden grows — each BMad Method release requires manual prompt porting to Ensi.

### Technique 3: Reverse Brainstorming (How to Guarantee Failure)
- Make onboarding require 10 steps and a config file.
- Let the Analyst produce a 10-page brief that nobody reads.
- Make sessions non-resumable — lose all progress on disconnection.
- Never validate that ACP actually works with Multica daemon before building 3 agents.
- Invert: **onboarding must be one command; briefs must be scannable in 2 minutes; sessions must be resumable; ACP integration must be spiked first.**

---

## 11. Recommended Next Steps for PM Agent

1. **Validate ACP + Multica integration** — spike a minimal "hello world" ACP agent registered with Multica daemon before committing to this stack. (Risk #1 and #2 mitigation.)
2. **Extract and test BMad prompts** — run the Analyst, PM, and Architect prompts standalone via Anthropic API to confirm they produce useful output without IDE context. (Assumption #2 validation.)
3. **Define the `.ensi/state.json` schema** — model the state machine explicitly before writing any code. The PM should own the stage transition rules.
4. **Write the PRD** — prioritise: (a) Analyst stage end-to-end, (b) PM stage, (c) Architect stage, (d) session resume. Each stage is a releasable increment.
5. **Identify a design partner** — one developer or team willing to run Ensi on a real greenfield project before public release. Recruit from BMad Method community (Discord/GitHub Discussions).
