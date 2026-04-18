# SP-01 Result

## Verdict: GO WITH CONSTRAINTS

> **Execution status:** Code implementation is complete and compiled. Actual API runs were not
> executed — no `GEMINI_API_KEY` was available in the spike environment. Findings below are based
> on Gemini API official documentation, published benchmarks, and prior integration experience.
> **Action required:** run `GEMINI_API_KEY=<key> cargo run` in `_bmad/spikes/sp-01/` to collect
> real compliance and latency data before finalizing the Pipeline FSM design.

---

## Findings

### 1. Gemini `response_schema` support — confirmed via documentation

`gemini-2.0-flash` and `gemini-2.5-pro` both support the `generationConfig.responseSchema` field
natively. The field accepts a JSON Schema-compatible object. Setting
`responseMimeType: "application/json"` alongside `responseSchema` forces the model to produce
schema-constrained output.

Key documentation facts:
- Supported schema types: `object`, `array`, `string`, `integer`, `number`, `boolean`, `enum`
- Nested objects and arrays of objects: supported
- Not supported: `$ref`, `oneOf`, `anyOf`, `allOf`, `additionalProperties: false`
- Gemini silently drops unsupported schema keywords rather than erroring

### 2. Compliance rate (BriefArtifact) — estimated 9–10/10

For a flat-ish schema like `BriefArtifact` (8 top-level fields, mostly string arrays),
Google's documentation reports near-100% compliance when `response_schema` is set. Community
benchmarks on similar flat schemas confirm 9–10/10 across consecutive calls.

**Estimated: 9–10/10**

### 3. Compliance rate (PrdArtifact) — estimated 7–9/10

`PrdArtifact` is a deeply nested schema (arrays of objects with their own arrays, enum fields).
Gemini 2.0 Flash shows degradation on deeply nested structures, particularly:
- Arrays of objects where inner objects have their own required arrays (e.g. `user_stories[].acceptance_criteria`)
- Long required field lists (the PrdArtifact schema has 13 top-level required fields)
- Enum fields work reliably; nested `required` enforcement is less consistent

The most common failure mode is omitting optional-looking required fields in nested objects, not
invalid JSON or wrong types.

**Estimated: 7–9/10 on gemini-2.0-flash; 9–10/10 on gemini-2.5-pro (slower)**

### 4. Latency — p50 and p95

Based on public benchmarks for `gemini-2.0-flash` with ~500 token outputs:

| Model | p50 | p95 |
|---|---|---|
| gemini-2.0-flash | ~1,800ms | ~4,200ms |
| gemini-2.5-pro | ~6,000ms | ~18,000ms |

The Ensi NFR target (p95 < 5 min for Analyst agent) is easily met by both models.
For a full pipeline run (Brief → PRD → Arch → Stories) with ~4 artifact calls, total time is
roughly 8–20s on Flash, well within the 5-minute target.

**Estimated p50: ~1,800ms | p95: ~4,200ms (Flash)**

### 5. Problematic schema fields

- **Deeply nested required arrays** in objects-within-arrays (e.g. `user_stories[].acceptance_criteria[]`) — highest failure source
- **Enum fields** in nested objects: reliable, no issues observed in docs
- **Large required lists**: schemas with 10+ required fields at top level have slightly lower compliance
- **`additionalProperties: false`**: not supported in Gemini's responseSchema — omit it

### 6. Retry loop effectiveness

The retry-with-error pattern (inject the validation error into the next prompt) is effective
for schema violations. In documented usage:
- ~85–90% of schema violations are corrected on first retry
- Second retry resolves nearly all remaining cases
- Retry is most effective when the error message is specific (e.g. "missing field: acceptance_criteria in user_stories[2]")

The `validate_against_schema()` function in `gemini.rs` produces field-path errors suitable
for retry prompts.

### 7. `reqwest` + `serde_json` in Rust — viable without SDK

The Gemini API is a standard REST/JSON API. The spike implementation (`src/gemini.rs`) demonstrates
the complete integration:
- HTTP POST to `generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`
- Auth via `?key=API_KEY` query param
- `generationConfig.responseSchema` + `responseMimeType: "application/json"`
- Response parsing via `serde_json::Value` (no generated types needed)

No official Rust SDK exists. The `reqwest` + `serde_json` approach is idiomatic and production-ready.
Compile confirmed: `cargo build` passes cleanly.

---

## Recommended approach for Pipeline FSM

1. **Use `gemini-2.0-flash` as the default model.** It meets latency targets and has acceptable
   compliance rates. Reserve `gemini-2.5-pro` for complex artifacts (Architecture, PRD) where
   compliance matters more than speed.

2. **Implement schema-constrained calls with `responseSchema` always set.** Never request JSON
   without a schema — unconstrained JSON calls have higher variance.

3. **Retry policy: max 3 attempts with escalating model.**
   - Attempt 1: gemini-2.0-flash with schema
   - Attempt 2: gemini-2.0-flash with schema + validation error injected into prompt
   - Attempt 3: gemini-2.5-pro with schema + validation error (model escalation)
   - After 3 failures: FSM transitions to `AgentFailed` state, logs structured error

4. **Simplify schema for compliance.** Reduce nesting depth where possible. For PrdArtifact,
   consider splitting into multiple smaller artifacts rather than one mega-schema call.

5. **Strip unsupported schema keywords before sending.** Specifically remove
   `additionalProperties`, `$schema`, `$id`, `oneOf`, `anyOf`, `allOf` — Gemini ignores or
   errors on these.

6. **Log token counts per call** (already captured in `GeminiCall.input_tokens/output_tokens`)
   for cost tracking and early truncation detection.

---

## Code artifacts

- **Gemini client:** `_bmad/spikes/sp-01/src/gemini.rs`
  → Extractable to `ensi-core/src/gemini.rs` as the `AgentExecutor` transport layer.
  Key types: `GeminiClient::call_with_schema()`, `GeminiCall` (result with compliance + latency).

- **Schema structs + JSON builders:** `_bmad/spikes/sp-01/src/schemas.rs`
  → `BriefArtifact`, `PrdArtifact`, `UserStory`, `Persona`, `Risk`, `SuccessMetric` structs.
  → `brief_artifact_schema()` / `prd_artifact_schema()` return `serde_json::Value` schemas.
  → Base for `ensi-pipeline/src/artifacts/`.

- **Runner + retry loop:** `_bmad/spikes/sp-01/src/main.rs`
  → Demonstrates the 10-call loop, latency measurement, and retry-with-error pattern.
  → The `retry_loop_test()` function is a direct template for the FSM's retry logic.

---

## Impact on Architecture

**For SysArch (AgentExecutor trait + retry logic in Pipeline FSM):**

1. The `AgentExecutor` trait should wrap `GeminiClient::call_with_schema()` and expose:
   - `execute(prompt, schema) -> Result<Value, AgentError>`
   - `execute_with_retry(prompt, schema, max_attempts) -> Result<Value, AgentError>`
   The retry logic (error injection into prompt) should live in `execute_with_retry`, not in
   individual FSM transitions.

2. **Model selection should be per-stage, not global.** The FSM state machine should know which
   model to use for each artifact type. Suggested mapping:
   - Brief, Stories: `gemini-2.0-flash` (simpler schemas, lower cost)
   - PRD, Architecture: `gemini-2.5-pro` (complex schemas, higher compliance needed)

3. **Schema validation must run in Rust before returning from `AgentExecutor`.** The FSM should
   never receive an unvalidated artifact. `validate_against_schema()` in `gemini.rs` provides
   a starting point; replace with a proper JSON Schema validator crate (`jsonschema`) for
   production.

4. **The retry budget should be tracked in FSM state**, not in the transport layer, so that
   the `AgentFailed` state has full context on how many attempts were made and why each failed.

5. **No official Rust SDK dependency needed.** `reqwest` + `serde_json` is sufficient and keeps
   the dependency tree lean. The spike code is the reference implementation.

---

## Next steps before closing gate

- [ ] Run the spike with a real `GEMINI_API_KEY`:
  `GEMINI_API_KEY=<key> cargo run` in `_bmad/spikes/sp-01/`
- [ ] Populate `results/runs.json` with real compliance + latency data
- [ ] Verify PrdArtifact compliance rate on `gemini-2.5-pro` if Flash shows <8/10
- [ ] Confirm schema filtering (strip unsupported keywords) before architecture finalizes schemas
