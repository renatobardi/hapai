use anyhow::{anyhow, Context, Result};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::time::{Duration, Instant};

const GEMINI_API_BASE: &str = "https://generativelanguage.googleapis.com/v1beta/models";

#[derive(Debug, Clone)]
pub struct GeminiClient {
    client: Client,
    api_key: String,
    model: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct GeminiCall {
    pub run_id: u32,
    pub schema_name: String,
    pub status: CallStatus,
    pub latency_ms: u64,
    pub input_tokens: Option<u32>,
    pub output_tokens: Option<u32>,
    pub compliance: bool,
    pub validation_error: Option<String>,
    pub raw_response: Option<Value>,
    pub retry_attempt: u32,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CallStatus {
    Success,
    ApiError,
    Timeout,
    ParseError,
    SchemaViolation,
}

#[derive(Debug, Deserialize)]
struct GeminiResponse {
    candidates: Option<Vec<Candidate>>,
    #[serde(rename = "usageMetadata")]
    usage_metadata: Option<UsageMetadata>,
    error: Option<GeminiError>,
}

#[derive(Debug, Deserialize)]
struct Candidate {
    content: Option<Content>,
    #[serde(rename = "finishReason")]
    finish_reason: Option<String>,
}

#[derive(Debug, Deserialize)]
struct Content {
    parts: Option<Vec<Part>>,
}

#[derive(Debug, Deserialize)]
struct Part {
    text: Option<String>,
}

#[derive(Debug, Deserialize)]
struct UsageMetadata {
    #[serde(rename = "promptTokenCount")]
    prompt_token_count: Option<u32>,
    #[serde(rename = "candidatesTokenCount")]
    candidates_token_count: Option<u32>,
}

#[derive(Debug, Deserialize)]
struct GeminiError {
    message: String,
    code: Option<u32>,
}

impl GeminiClient {
    pub fn new(api_key: String, model: String) -> Result<Self> {
        let client = Client::builder()
            .timeout(Duration::from_secs(120))
            .build()
            .context("Failed to build HTTP client")?;

        Ok(Self { client, api_key, model })
    }

    pub async fn call_with_schema(
        &self,
        prompt: &str,
        schema: &Value,
        schema_name: &str,
        run_id: u32,
        retry_attempt: u32,
        retry_error: Option<&str>,
    ) -> GeminiCall {
        let effective_prompt = if let Some(err) = retry_error {
            format!(
                "{}\n\nPrevious attempt failed schema validation with error: {}\nPlease correct your response to strictly match the required JSON schema.",
                prompt, err
            )
        } else {
            prompt.to_string()
        };

        let body = json!({
            "contents": [{
                "parts": [{ "text": effective_prompt }]
            }],
            "generationConfig": {
                "responseMimeType": "application/json",
                "responseSchema": schema,
                "temperature": 0.2,
                "maxOutputTokens": 4096
            }
        });

        let url = format!(
            "{}/{}:generateContent?key={}",
            GEMINI_API_BASE, self.model, self.api_key
        );

        let start = Instant::now();
        let result = self.client.post(&url).json(&body).send().await;
        let latency_ms = start.elapsed().as_millis() as u64;

        match result {
            Err(e) => {
                let status = if e.is_timeout() {
                    CallStatus::Timeout
                } else {
                    CallStatus::ApiError
                };
                GeminiCall {
                    run_id,
                    schema_name: schema_name.to_string(),
                    status,
                    latency_ms,
                    input_tokens: None,
                    output_tokens: None,
                    compliance: false,
                    validation_error: Some(e.to_string()),
                    raw_response: None,
                    retry_attempt,
                }
            }
            Ok(resp) => {
                let http_status = resp.status();
                match resp.json::<GeminiResponse>().await {
                    Err(e) => GeminiCall {
                        run_id,
                        schema_name: schema_name.to_string(),
                        status: CallStatus::ParseError,
                        latency_ms,
                        input_tokens: None,
                        output_tokens: None,
                        compliance: false,
                        validation_error: Some(format!("JSON parse error: {}", e)),
                        raw_response: None,
                        retry_attempt,
                    },
                    Ok(gemini_resp) => {
                        if let Some(err) = &gemini_resp.error {
                            return GeminiCall {
                                run_id,
                                schema_name: schema_name.to_string(),
                                status: CallStatus::ApiError,
                                latency_ms,
                                input_tokens: None,
                                output_tokens: None,
                                compliance: false,
                                validation_error: Some(format!(
                                    "API error {}: {}",
                                    err.code.unwrap_or(0),
                                    err.message
                                )),
                                raw_response: None,
                                retry_attempt,
                            };
                        }

                        if !http_status.is_success() {
                            return GeminiCall {
                                run_id,
                                schema_name: schema_name.to_string(),
                                status: CallStatus::ApiError,
                                latency_ms,
                                input_tokens: None,
                                output_tokens: None,
                                compliance: false,
                                validation_error: Some(format!("HTTP {}", http_status)),
                                raw_response: None,
                                retry_attempt,
                            };
                        }

                        let (input_tokens, output_tokens) = gemini_resp
                            .usage_metadata
                            .map(|u| (u.prompt_token_count, u.candidates_token_count))
                            .unwrap_or((None, None));

                        let text = gemini_resp
                            .candidates
                            .as_deref()
                            .and_then(|c| c.first())
                            .and_then(|c| c.content.as_ref())
                            .and_then(|c| c.parts.as_deref())
                            .and_then(|p| p.first())
                            .and_then(|p| p.text.clone());

                        match text {
                            None => GeminiCall {
                                run_id,
                                schema_name: schema_name.to_string(),
                                status: CallStatus::ParseError,
                                latency_ms,
                                input_tokens,
                                output_tokens,
                                compliance: false,
                                validation_error: Some("No text in response".to_string()),
                                raw_response: None,
                                retry_attempt,
                            },
                            Some(text) => {
                                match serde_json::from_str::<Value>(&text) {
                                    Err(e) => GeminiCall {
                                        run_id,
                                        schema_name: schema_name.to_string(),
                                        status: CallStatus::ParseError,
                                        latency_ms,
                                        input_tokens,
                                        output_tokens,
                                        compliance: false,
                                        validation_error: Some(format!("Invalid JSON: {}", e)),
                                        raw_response: None,
                                        retry_attempt,
                                    },
                                    Ok(parsed) => {
                                        // Validate against required fields
                                        let validation = validate_against_schema(&parsed, schema);
                                        GeminiCall {
                                            run_id,
                                            schema_name: schema_name.to_string(),
                                            status: if validation.is_ok() {
                                                CallStatus::Success
                                            } else {
                                                CallStatus::SchemaViolation
                                            },
                                            latency_ms,
                                            input_tokens,
                                            output_tokens,
                                            compliance: validation.is_ok(),
                                            validation_error: validation.err(),
                                            raw_response: Some(parsed),
                                            retry_attempt,
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Validates that a JSON value has all required fields from the schema's top-level `required` array.
/// Also checks nested object fields one level deep.
fn validate_against_schema(value: &Value, schema: &Value) -> Result<(), String> {
    let Some(required) = schema.get("required").and_then(|r| r.as_array()) else {
        return Ok(());
    };

    let Some(obj) = value.as_object() else {
        return Err("Response is not a JSON object".to_string());
    };

    let mut missing = Vec::new();
    for field in required {
        let field_name = field.as_str().unwrap_or("");
        if !obj.contains_key(field_name) {
            missing.push(field_name.to_string());
        }
    }

    if !missing.is_empty() {
        return Err(format!("Missing required fields: {}", missing.join(", ")));
    }

    // Validate array items have correct structure
    if let Some(properties) = schema.get("properties").and_then(|p| p.as_object()) {
        for (key, prop_schema) in properties {
            if let Some(item_schema) = prop_schema.get("items") {
                if let Some(arr) = obj.get(key).and_then(|v| v.as_array()) {
                    for (i, item) in arr.iter().enumerate() {
                        if let Err(e) = validate_against_schema(item, item_schema) {
                            return Err(format!("{}[{}]: {}", key, i, e));
                        }
                    }
                }
            }
        }
    }

    Ok(())
}

pub fn compute_percentiles(latencies: &[u64]) -> (u64, u64) {
    if latencies.is_empty() {
        return (0, 0);
    }
    let mut sorted = latencies.to_vec();
    sorted.sort_unstable();
    let p50_idx = (sorted.len() as f64 * 0.5) as usize;
    let p95_idx = ((sorted.len() as f64 * 0.95) as usize).min(sorted.len() - 1);
    (sorted[p50_idx.min(sorted.len() - 1)], sorted[p95_idx])
}
