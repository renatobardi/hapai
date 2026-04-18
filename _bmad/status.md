# BMAD Pipeline Status

## Project: Ensi — BMAD 4 Multica

| Phase | Agent | Status | Artefacts |
|---|---|---|---|
| Discovery / Brief | Analyst | ✅ Complete (2026-04-17) | `_bmad/docs/product-brief.md`, `_bmad/docs/brief-artifact.json` |
| Planning / PRD | PM (Curly) | ✅ Complete (2026-04-17) | `_bmad/docs/product-prd.md`, `_bmad/docs/prd-artifact.json` |
| Architecture | Architect | ⏳ Pending | `_bmad/docs/architecture.md` |
| Development | Developer (v2) | ⏳ Pending | — |
| Review | Code Reviewer | ⏳ Pending | — |

## Next Agent
**Load the Architect agent.** Input: `_bmad/docs/prd-artifact.json`. Output: `_bmad/docs/architecture-artifact.json` + `_bmad/docs/product-architecture.md` with ADR, stack choices, and component design.

## PRD Summary (PM Agent — Curly, 2026-04-17)

**2 validation spikes** gating the full build:
- SP-01: ACP + Multica daemon integration
- SP-02: BMad prompt portability via Anthropic API

**5 MVP pipeline stages:** Discovery → Planning → Architecture → Development → Review
(Deploy + Observability deferred to v2)

**10 features classified:** 7 must / 2 should / 1 could (for must-haves: F-001 through F-007)

**17 functional requirements** across protocol, pipeline, artefacts, session state, onboarding (FR-01 to FR-17)

**15 non-functional requirements** covering performance, reliability, security, scalability, observability, compatibility (NFR-01 to NFR-15)

**8 epics** (2 spikes + 6 feature epics)

**12 stories** (2 spike stories + 10 user stories, US-01 to US-10)

**5 artifact schemas** fully defined in `prd-artifact.json`:
- `BriefArtifact` (Analyst / Discovery)
- `PrdArtifact` (PM / Planning) — this document
- `ArchitectureArtifact` (Architect / Architecture)
- `SprintPlanArtifact` (Scrum Master / Development — v2)
- `CodeReviewArtifact` (Code Reviewer / Review)

**MVP scope:** 3 agents (Analyst, PM, Architect), greenfield only, Anthropic API only, Node.js v20+

**8-week schedule:** validated as achievable for a 1–2 person team, assuming both spikes pass in Week 1

**13 items out of scope for v1** (explicitly documented to prevent scope creep)

**10 open questions** deferred to Architect and engineering
