# SP-01 Result

> **Execution status:** Real API run completed on 2026-04-18 (T-008).
> Models: `gemini-2.5-flash` (BriefArtifact) and `gemini-2.5-pro` (PrdArtifact).
> Note: `gemini-2.0-flash` is deprecated for new accounts — replaced by `gemini-2.5-flash`.

## Verdict: GO

---

## Findings

### 1. Compliance rate (BriefArtifact — gemini-2.5-flash): **10/10**

100% compliance across 10 consecutive runs. `responseSchema` fully enforces the schema — the
model produced valid JSON matching all required fields on every call. No retries needed.

### 2. Compliance rate (PrdArtifact — gemini-2.5-pro): **5/5**

100% compliance across 5 runs. Required increasing `maxOutputTokens` from 4096 → 8192 to avoid
response truncation (the PrdArtifact schema generates ~6,000-7,000 tokens of output). With 8192
tokens, all 5 calls completed successfully.

### 3. Latency — measured p50 and p95

| Model | Schema | p50 | p95 |
|---|---|---|---|
| gemini-2.5-flash | BriefArtifact | 6,361ms | 7,980ms |
| gemini-2.5-pro | PrdArtifact | 42,754ms | 50,285ms |

**NFR status: PASS.** Typical pipeline (Brief + PRD + Arch + Stories + Review) with 2 Pro calls
and 3 Flash calls: ~100s Pro + ~25s Flash = **~125s total**, well within the 5-minute (300s) NFR.
Worst case (p95 on all stages): ~165s — still within NFR.

### 4. Problematic schema fields

None observed at BriefArtifact level. PrdArtifact required higher token budget:
- `maxOutputTokens: 4096` causes truncation on Pro — use `8192` for all calls
- Schema keywords to strip before sending: `additionalProperties`, `$ref`, `oneOf`, `anyOf`
  (Gemini silently ignores or errors on these)

### 5. Retry loop effectiveness

The retry loop was **not triggered** in any of the 15 runs. More significantly: when the retry
test sent a deliberately broken prompt ("respond only with `{\"title\": \"test\"}`"), the model
with `responseSchema` set **ignored the instruction and produced a fully compliant BriefArtifact**
anyway. The `responseSchema` constraint is stronger than contradictory prompt instructions.

**Implication:** Retry loop is still recommended as a safety net for production edge cases, but
expected trigger rate is near-zero when `responseSchema` is consistently set.

### 6. `reqwest` + `serde_json` in Rust — confirmed viable

No official Rust SDK needed. The `gemini.rs` client handles auth, schema injection, response
parsing, and validation in ~300 lines. Ready to extract to `ensi-daemon`.

---

## Recommended approach for Pipeline FSM

1. **Always set `responseSchema`.** It eliminates compliance failures — do not make unschema'd
   JSON calls. The schema is the primary correctness guarantee.

2. **Set `maxOutputTokens: 8192` for all calls.** 4096 truncates complex Pro-stage outputs.

3. **Model per stage (updated for API availability):**
   - Brief, Stories, Review: `gemini-2.5-flash` (~6-8s per call)
   - PRD, Architecture: `gemini-2.5-pro` (~43-50s per call)
   - `gemini-2.0-flash` is deprecated for new accounts — do not use.

4. **Retry policy: max 3 attempts with error injection (keep as safety net).**
   Expected trigger rate ~0% in practice, but retain for production resilience.
   - Attempt 1: model with `responseSchema`
   - Attempt 2: same model + validation error injected into prompt
   - Attempt 3: escalate to `gemini-2.5-pro` if on Flash (or retry Pro with error)
   - After 3 failures: FSM → `AgentFailed` state

5. **Strip unsupported schema keywords** before sending:
   `additionalProperties`, `$schema`, `$id`, `oneOf`, `anyOf`, `allOf`

---

## Code artifacts

- **Gemini client:** `_bmad/spikes/sp-01/src/gemini.rs`
  → Ready to extract to `ensi-daemon/src/gemini_client.rs`.

- **Schema builders:** `_bmad/spikes/sp-01/src/schemas.rs`
  → Base for `ensi-pipeline/src/artifacts/`.

- **Runner:** `_bmad/spikes/sp-01/src/main.rs`
  → Dual-model pattern (flash for brief, pro for prd) is the reference for AgentExecutor.

- **Results:** `_bmad/spikes/sp-01/results/runs.json`
  → Full 16-entry dataset with latency, compliance, token counts per run.

---

## Impact on Architecture

1. **Replace `gemini-2.0-flash` with `gemini-2.5-flash`** in `AgentExecutor::model_for_stage()`
   and `architecture-artifact.json`. The model is deprecated for new API keys.

2. **`maxOutputTokens: 8192` is required** — not optional. Set it globally in `GeminiClient`.

3. **The retry budget can be relaxed** — 2 retries for Flash stages (100% compliance observed),
   3 for Pro stages as conservative buffer.

4. **No schema compliance risk for Week 3.** Gate is GO — Pipeline FSM can be built with
   confidence in the Gemini structured output layer.
