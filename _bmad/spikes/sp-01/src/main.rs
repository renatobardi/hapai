mod gemini;
mod schemas;

use anyhow::{Context, Result};
use gemini::{compute_percentiles, GeminiCall, GeminiClient};
use schemas::{brief_artifact_schema, prd_artifact_schema};
use serde_json::json;

const ENSI_BRIEF_PROMPT: &str = r#"
You are an AI product analyst. Generate a complete BriefArtifact for a product called "Ensi".

Ensi is an AI-powered product development pipeline that automates the journey from product brief to
deployed code. It uses LLM agents orchestrated by a finite state machine (Pipeline FSM) to produce
structured artifacts: Brief → PRD → Architecture → Stories → Code.

Each artifact is validated against a strict JSON schema before the pipeline advances. The pipeline
runs on Rust with async agents calling Gemini API for artifact generation.

Generate a realistic BriefArtifact for Ensi's MVP, filling all required fields with meaningful content.
"#;

const ENSI_PRD_PROMPT: &str = r#"
You are an AI product analyst. Generate a complete PrdArtifact for a product called "Ensi".

Ensi is an AI-powered product development pipeline that automates the journey from product brief to
deployed code. It uses LLM agents orchestrated by a finite state machine (Pipeline FSM) to produce
structured artifacts: Brief → PRD → Architecture → Stories → Code.

Key capabilities:
- Multi-agent orchestration with FSM state transitions
- Structured output validation at each pipeline stage
- Rust backend with async Gemini API integration
- Multica platform integration for issue tracking

Generate a complete, realistic PrdArtifact for Ensi's MVP. Include:
- 2-3 target personas (PM, Backend Dev, Architect)
- 4-5 functional requirements sections
- 5-7 user stories with full acceptance criteria
- Non-functional requirements for performance, security, scalability
- 3-5 risks with mitigations
- 3-4 success metrics with baselines and targets

Fill all required fields with detailed, meaningful content.
"#;

#[tokio::main]
async fn main() -> Result<()> {
    let api_key = std::env::var("GEMINI_API_KEY")
        .or_else(|_| std::env::var("GOOGLE_API_KEY"))
        .context("GEMINI_API_KEY or GOOGLE_API_KEY environment variable required")?;

    let model = std::env::var("GEMINI_MODEL")
        .unwrap_or_else(|_| "gemini-2.0-flash".to_string());

    println!("=== SP-01: Gemini Structured Output Spike ===");
    println!("Model: {}", model);
    println!("Starting 10x BriefArtifact calls...\n");

    let client = GeminiClient::new(api_key, model)?;
    let brief_schema = brief_artifact_schema();
    let prd_schema = prd_artifact_schema();

    let mut all_runs: Vec<GeminiCall> = Vec::new();

    // --- Phase 1: BriefArtifact, 10 runs ---
    let mut brief_latencies = Vec::new();
    let mut brief_compliant = 0u32;

    for i in 1..=10 {
        print!("  BriefArtifact run {}/10... ", i);
        let call = client
            .call_with_schema(ENSI_BRIEF_PROMPT, &brief_schema, "BriefArtifact", i, 0, None)
            .await;
        let compliant = call.compliance;
        let latency = call.latency_ms;
        println!("{}  {}ms", if compliant { "PASS" } else { "FAIL" }, latency);
        if compliant {
            brief_compliant += 1;
        }
        brief_latencies.push(latency);
        all_runs.push(call);
    }

    let (brief_p50, brief_p95) = compute_percentiles(&brief_latencies);
    println!(
        "\nBriefArtifact: {}/10 compliant | p50={}ms | p95={}ms\n",
        brief_compliant, brief_p50, brief_p95
    );

    // --- Phase 2: PrdArtifact, 5 runs ---
    println!("Starting 5x PrdArtifact calls...\n");
    let mut prd_latencies = Vec::new();
    let mut prd_compliant = 0u32;

    for i in 1..=5 {
        print!("  PrdArtifact run {}/5... ", i);
        let call = client
            .call_with_schema(ENSI_PRD_PROMPT, &prd_schema, "PrdArtifact", i, 0, None)
            .await;
        let compliant = call.compliance;
        let latency = call.latency_ms;
        println!("{}  {}ms", if compliant { "PASS" } else { "FAIL" }, latency);
        if compliant {
            prd_compliant += 1;
        }
        prd_latencies.push(latency);
        all_runs.push(call);
    }

    let (prd_p50, prd_p95) = compute_percentiles(&prd_latencies);
    println!(
        "\nPrdArtifact: {}/5 compliant | p50={}ms | p95={}ms\n",
        prd_compliant, prd_p50, prd_p95
    );

    // --- Phase 3: Retry loop test ---
    println!("Testing retry loop (forced schema error → re-prompt)...\n");
    let retry_call = retry_loop_test(&client, &brief_schema).await;
    all_runs.push(retry_call);

    // --- Save results ---
    let results_path = "results/runs.json";
    let summary = json!({
        "model": std::env::var("GEMINI_MODEL").unwrap_or_else(|_| "gemini-2.0-flash".to_string()),
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "brief_artifact": {
            "total_runs": 10,
            "compliant": brief_compliant,
            "compliance_rate": brief_compliant as f64 / 10.0,
            "p50_latency_ms": brief_p50,
            "p95_latency_ms": brief_p95,
        },
        "prd_artifact": {
            "total_runs": 5,
            "compliant": prd_compliant,
            "compliance_rate": prd_compliant as f64 / 5.0,
            "p50_latency_ms": prd_p50,
            "p95_latency_ms": prd_p95,
        },
        "runs": all_runs
    });

    std::fs::write(results_path, serde_json::to_string_pretty(&summary)?)?;
    println!("\nResults saved to {}", results_path);
    println!("\n=== SUMMARY ===");
    println!("BriefArtifact compliance: {}/10", brief_compliant);
    println!("PrdArtifact compliance:   {}/5", prd_compliant);
    println!("Brief p50/p95: {}ms / {}ms", brief_p50, brief_p95);
    println!("PRD   p50/p95: {}ms / {}ms", prd_p50, prd_p95);

    Ok(())
}

/// Intentionally forces a schema validation failure then retries with the error in the prompt.
async fn retry_loop_test(client: &GeminiClient, schema: &serde_json::Value) -> GeminiCall {
    let broken_prompt = "Respond with a JSON object that has ONLY a 'title' field: {\"title\": \"test\"}";

    println!("  Retry test: sending intentionally incomplete response...");
    let first_attempt = client
        .call_with_schema(broken_prompt, schema, "BriefArtifact_retry_test", 99, 0, None)
        .await;

    if first_attempt.compliance {
        println!("  Retry test: first attempt unexpectedly passed — retry not needed");
        return first_attempt;
    }

    let error_msg = first_attempt
        .validation_error
        .clone()
        .unwrap_or_else(|| "schema validation failed".to_string());

    println!("  Retry test: first attempt FAILED ({}), retrying with error...", error_msg);
    let retry = client
        .call_with_schema(
            ENSI_BRIEF_PROMPT,
            schema,
            "BriefArtifact_retry_test",
            99,
            1,
            Some(&error_msg),
        )
        .await;

    println!(
        "  Retry test: {} after retry  {}ms",
        if retry.compliance { "PASS" } else { "FAIL" },
        retry.latency_ms
    );
    retry
}
